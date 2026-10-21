"""Prueba reglas con reloj/Engine simulados y HTTP efimero; nunca toca Docker real."""
import copy,datetime,json,tempfile,threading,unittest
from unittest.mock import patch
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import supervisor as s

def contenedor(servicio='api',estado='running'):
    return {'Id':'id-'+servicio,'Name':'/'+s.PROYECTO+'-'+servicio+'-1','Config':{'Labels':{'com.docker.compose.project':s.PROYECTO,'com.docker.compose.service':servicio}},'State':{'Status':estado,'StartedAt':'2026-01-01T00:00:00.123456789Z','OOMKilled':False},'RestartCount':0}
AHORA=1800000000
MALO={'ok':False,'causa':'funcional'}
BUENO={'ok':True,'causa':'salud'}
class Reglas(unittest.TestCase):
    def decidir(self,st=None,prueba=MALO,habilitado=True,maintenance=False,now=AHORA,nombre='api',d=None):
        return s.decidir(nombre,d or contenedor(nombre),prueba,st or {},now,habilitado,maintenance)
    def fallos(self,**kw):
        st={}
        for i in range(3):st,act=self.decidir(st,now=AHORA+i*15,**kw)
        return st,act
    def test_transiciones_recuperacion(self):
        st,_=self.decidir(prueba=BUENO);self.assertEqual(st['estado'],'healthy')
        st,a=self.decidir(st);self.assertFalse(a);self.assertEqual(st['estado'],'unhealthy')
        st,a=self.decidir(st);self.assertFalse(a)
        st,a=self.decidir(st);self.assertTrue(a);self.assertEqual(st['estado'],'recovering')
        st,a=self.decidir(st,prueba=BUENO,now=AHORA+20);self.assertFalse(a);self.assertEqual(st['estado'],'healthy');self.assertEqual(st['recuperacion_segundos'],20)
    def test_observar_no_reinicia(self):self.assertFalse(self.fallos(habilitado=False)[1])
    def test_dependencia_no_reinicia(self):self.assertFalse(self.fallos(prueba={'ok':False,'causa':'dependencia'})[1])
    def test_mantenimiento(self):self.assertFalse(self.fallos(maintenance=True)[1])
    def test_arranque(self):self.assertFalse(self.decidir(now=1767225605)[1])
    def test_cooldown(self):
        st,_=self.fallos();st,a=self.decidir(st,now=AHORA+45);self.assertFalse(a);self.assertEqual(st['estado'],'cooldown')
    def test_limite_persistente(self):
        st={'intentos':[AHORA-900,AHORA-600,AHORA-300],'fallos':3}
        st,a=self.decidir(st);self.assertFalse(a);self.assertEqual(st['estado'],'bloqueado')
    def test_expira_ventana(self):
        st={'intentos':[AHORA-4000]*3,'fallos':3};self.assertTrue(self.decidir(st)[1])
    def test_postgres_solo_alerta(self):
        for n in ['postgres','postgres_lectura','prometheus','cadvisor','docker_socket_proxy']:self.assertFalse(self.fallos(nombre=n)[1])
    def test_detenido_manual(self):self.assertFalse(self.decidir(d=contenedor(estado='exited'))[1])
    def test_oom_no_reinicia(self):
        d=contenedor();d['State']['OOMKilled']=True;self.assertFalse(self.decidir({'fallos':3},d=d)[1])
    def test_otro_proyecto(self):
        d=contenedor();d['Config']['Labels']['com.docker.compose.project']='ajeno';self.assertFalse(self.decidir({'fallos':3},d=d)[1])
    def test_mongodb_redis_postgres15_fuera(self):
        for n in ['mongodb','redis_server','postgres2']:
            with self.assertRaises(AssertionError):s.reiniciar(n,contenedor(n),{n:'id-'+n})
    def test_id_cambiado(self):
        with self.assertRaises(AssertionError):s.reiniciar('api',contenedor(),{'api':'id-viejo'})
    def test_revalida_etiquetas(self):
        d=contenedor();d['Config']['Labels']['com.docker.compose.project']='otro'
        with patch.object(s,'comando',return_value=json.dumps([d])) as c:
            with self.assertRaises(AssertionError):s.reiniciar('api',contenedor(),{'api':'id-api'})
            self.assertEqual(c.call_count,1)
    def test_solo_restart_id_fijado(self):
        with patch.object(s,'comando',side_effect=[json.dumps([contenedor()]),'id-api']) as c:
            s.reiniciar('api',contenedor(),{'api':'id-api'});self.assertEqual(c.call_args.args[0],['docker','restart','--time','10','id-api'])
    def test_api_degradada_no_reinicio(self):
        datos={n:contenedor(n) for n in s.SERVICIOS}
        for d in datos.values():d['NetworkSettings']={'Networks':{'monitoreo':{'IPAddress':'127.0.0.1'}}}
        def http(url):
            if 'disponibilidad' in url:return 200,b'{"lectura":true,"escritura":false}'
            if 'api/v1' in url:return 200,b'{"status":"success"}'
            if '/api/health' in url:return 200,b'{"database":"ok"}'
            return 200,b'pg_up 1'
        def sql(d,st):return {'ok':st,'causa':'salud' if st else 'dependencia','wal':1}
        with patch.object(s,'obtener',side_effect=http),patch.object(s,'sql',side_effect=sql):
            resultado=s.comprobar(datos);self.assertTrue(resultado['api']['ok']);self.assertEqual(resultado['api']['escritura'],0)
            self.assertFalse(self.decidir({'fallos':5},prueba=resultado['api'])[1])
    def test_engine_caido_sin_acciones(self):
        from pathlib import Path
        with tempfile.TemporaryDirectory() as td:
            base=Path(td);(base/'metricas').mkdir();(base/'activacion.json').write_text('{"api":"id-api"}')
            with patch.object(s,'comando',side_effect=RuntimeError()),patch.object(s,'reiniciar') as rein:
                s.ciclo(base,AHORA);rein.assert_not_called()
            self.assertIn('motor_no_disponible',(base/'estado.json').read_text())
    def test_observacion_ignora_activacion(self):
        from pathlib import Path
        with tempfile.TemporaryDirectory() as td:
            b=Path(td);(b/'metricas').mkdir();(b/'activacion.json').write_text('{"api":"id-api"}')
            (b/'estado.json').write_text(json.dumps({'api':{'fallos':3}}))
            datos={n:contenedor(n) for n in s.SERVICIOS};pruebas={n:MALO for n in s.SERVICIOS}
            with patch.object(s,'comando',return_value='27'),patch.object(s,'inventario',return_value=datos),patch.object(s,'comprobar',return_value=pruebas),patch.object(s,'reiniciar') as rein:
                s.ciclo(b,AHORA);rein.assert_not_called()
    def test_fallo_restart_preserva_presupuesto(self):
        from pathlib import Path
        with tempfile.TemporaryDirectory() as td:
            b=Path(td);(b/'metricas').mkdir();(b/'activacion.json').write_text('{"api":"id-api"}')
            (b/'estado.json').write_text(json.dumps({'api':{'fallos':3}}))
            datos={n:contenedor(n) for n in s.SERVICIOS};pruebas={n:BUENO for n in s.SERVICIOS};pruebas['api']=MALO
            with patch.object(s,'comando',return_value='27'),patch.object(s,'inventario',return_value=datos),patch.object(s,'comprobar',return_value=pruebas),patch.object(s,'reiniciar',side_effect=RuntimeError()):s.ciclo(b,AHORA,permitir_acciones=True)
            st=json.loads((b/'estado.json').read_text())['api'];self.assertEqual(st['estado'],'recuperacion_fallida');self.assertEqual(len(st['intentos']),1)
    def test_exclusion_dos_bucles(self):
        import fcntl,subprocess,sys
        from pathlib import Path
        with tempfile.TemporaryDirectory() as td:
            with (Path(td)/'proceso.lock').open('a') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                resultado=subprocess.run([sys.executable,str(Path(s.__file__)),'una-vez','--estado',td],text=True,capture_output=True)
                self.assertNotEqual(resultado.returncode,0)
                self.assertIn('BlockingIOError',resultado.stderr)
                self.assertFalse((Path(td)/'latido.json').exists())
    def test_politica_coincide_allowlist(self):
        self.assertEqual(set(s.POLITICA['autorreinicio']),s.AUTORIZADOS)
        self.assertEqual([s.POLITICA[k] for k in ['fallos','arranque','cooldown','max_reinicios']],[3,120,300,3])
    def test_unhealthy_no_es_exit(self):
        d=contenedor();d['State']['Health']={'Status':'unhealthy'}
        self.assertEqual(d['State']['Status'],'running')
        # La política Docker no es usada para decidir; solo fallos funcionales probados.
        self.assertFalse(self.decidir(d=d,prueba=BUENO)[1])
    def test_http_ficticio(self):
        class Falso(BaseHTTPRequestHandler):
            malo=True
            def do_GET(self):self.send_response(503 if self.malo else 200);self.end_headers();self.wfile.write(b'ok')
            def log_message(self,*args):pass
        server=ThreadingHTTPServer(('127.0.0.1',0),Falso);h=threading.Thread(target=server.serve_forever,daemon=True);h.start()
        try:
            url='http://127.0.0.1:'+str(server.server_port)
            with self.assertRaises(Exception):s.obtener(url)
            Falso.malo=False;self.assertEqual(s.obtener(url)[0],200)
        finally:server.shutdown();server.server_close();h.join()
if __name__=='__main__':unittest.main()
