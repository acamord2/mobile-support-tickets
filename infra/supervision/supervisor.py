#!/usr/bin/env python3
"""Supervisa solo Tickets; observa por defecto, persiste limites y nunca arranca bases o detenidos."""
import argparse,datetime,fcntl,json,os,subprocess,time,urllib.request
from pathlib import Path
POLITICA=json.loads((Path(__file__).parent/'politica.json').read_text())
PROYECTO='mobile-support-tickets-prueba-docker'
AUTORIZADOS={'api','grafana','blackbox','postgres_exporter','postgres_exporter_lectura'}
SERVICIOS=AUTORIZADOS|{'postgres','postgres_lectura','prometheus','cadvisor','docker_socket_proxy'}

def comando(args):
    """Acota ejecucion y evita imprimir salidas del motor que puedan incluir secretos."""
    p=subprocess.run(args,text=True,capture_output=True,timeout=12)
    if p.returncode:raise RuntimeError('Comando Docker no disponible')
    return p.stdout

def inventario():
    """Inspecciona nombres exactos, sin enumerar ni modificar contenedores de otros proyectos."""
    datos={}
    for s in sorted(SERVICIOS):
        try:
            d=json.loads(comando(['docker','inspect',PROYECTO+'-'+s+'-1']))[0]
            if not identidad(d,s):raise RuntimeError('Identidad no autorizada')
            datos[s]=d
        except RuntimeError:datos[s]=None
    return datos

def identidad(d,s):
    """Exige proyecto, servicio, nombre y ID antes de considerar cualquier accion."""
    l=d['Config'].get('Labels') or {}
    return s in SERVICIOS and l.get('com.docker.compose.project')==PROYECTO and l.get('com.docker.compose.service')==s and d['Name']=='/'+PROYECTO+'-'+s+'-1'

def obtener(url):
    """Consulta HTTP privada con limite; no registra cuerpos ni cabeceras sensibles."""
    with urllib.request.urlopen(url,timeout=3) as p:return p.status,p.read()

def ip(d):
    redes=d['NetworkSettings']['Networks']
    return next((v['IPAddress'] for k,v in redes.items() if k.endswith('_monitoreo')),next(v['IPAddress'] for v in redes.values() if v['IPAddress']))

def sql(d,standby):
    """Consulta metadatos bajo monitor_postgres; no usa password ni modifica estado persistente."""
    q="SET ROLE monitor_postgres; SELECT json_build_object('recuperacion',pg_is_in_recovery(),'readonly',current_setting('transaction_read_only'),'wal',(SELECT count(*) FROM pg_stat_wal_receiver WHERE status='streaming'),'emisores',(SELECT count(*) FROM pg_stat_replication WHERE state='streaming' AND sync_state='async'));"
    v=json.loads(comando(['docker','exec',d['Id'],'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','tickets_practica','-d','tickets_db','-c',q]).strip())
    ok=v['recuperacion']==standby and (not standby or v['readonly']=='on')
    return {'ok':ok,'causa':'salud' if ok else 'rol_sql_incorrecto','wal':v['wal'] if standby else v['emisores']}

def comprobar(datos):
    """Separa fallo funcional propio de dependencia, detencion, recursos y WAL; solo SELECT/HTTP."""
    resultado={}
    for s in ['postgres','postgres_lectura','prometheus','docker_socket_proxy','cadvisor','blackbox','grafana','postgres_exporter','postgres_exporter_lectura','api']:
        d=datos[s]
        if not d:resultado[s]={'ok':False,'causa':'ausente'};continue
        if d['State']['Status']!='running':resultado[s]={'ok':False,'causa':'detenido'};continue
        if d['State'].get('OOMKilled'):resultado[s]={'ok':False,'causa':'recursos'};continue
        try:
            if s in ['postgres','postgres_lectura']:
                resultado[s]=sql(d,s=='postgres_lectura');continue
            deps={'api':['postgres','postgres_lectura'],'postgres_exporter':['postgres'],'postgres_exporter_lectura':['postgres_lectura'],'grafana':['prometheus'],'cadvisor':['docker_socket_proxy']}.get(s,[])
            puertos={'api':8080,'grafana':3000,'prometheus':9090,'blackbox':9115,'cadvisor':8080,'docker_socket_proxy':2375,'postgres_exporter':9187,'postgres_exporter_lectura':9187}
            rutas={'api':'/api/health/disponibilidad','grafana':'/api/health','prometheus':'/-/ready','blackbox':'/-/healthy','cadvisor':'/healthz','docker_socket_proxy':'/_ping','postgres_exporter':'/metrics','postgres_exporter_lectura':'/metrics'}
            _,body=obtener('http://'+ip(d)+':'+str(puertos[s])+rutas[s])
            if s=='api':
                v=json.loads(body);ok=isinstance(v.get('lectura'),bool) and isinstance(v.get('escritura'),bool) and v['lectura']
                resultado[s]={'ok':ok,'causa':'salud' if ok else 'dependencia','lectura':int(v.get('lectura',False)),'escritura':int(v.get('escritura',False))};continue
            if s=='prometheus':
                _,v=obtener('http://'+ip(d)+':9090/api/v1/query?query=vector(1)');assert json.loads(v)['status']=='success'
            if s=='grafana':assert json.loads(body).get('database')=='ok'
            if s.startswith('postgres_exporter'):assert b'pg_up 1' in body
            resultado[s]={'ok':True,'causa':'salud'}
        except Exception:
            deps={'api':['postgres','postgres_lectura'],'postgres_exporter':['postgres'],'postgres_exporter_lectura':['postgres_lectura'],'grafana':['prometheus'],'cadvisor':['docker_socket_proxy']}.get(s,[])
            # Ante dependencia desconocida/fallida: diagnosticar, nunca reiniciar para probar.
            dependencia=any(not resultado.get(x,{}).get('ok',False) for x in deps)
            resultado[s]={'ok':False,'causa':'dependencia' if dependencia else 'funcional'}
    return resultado

def decidir(s,d,prueba,anterior,ahora,habilitado,mantenimiento,politica=POLITICA):
    """Maquina pura y testeable: healthy/unhealthy/recovering, mantenimiento, cooldown y presupuesto."""
    st=dict(anterior);st.setdefault('intentos',[]);st.setdefault('fallos',0)
    st['intentos']=[t for t in st['intentos'] if ahora-t<politica['ventana']]
    st['reintentos_total']=st.get('reintentos_total',0)
    if mantenimiento:st.update(estado='mantenimiento',fallos=0);return st,False
    if not d or not identidad(d,s):st.update(estado='ausente',fallos=0);return st,False
    if d['State']['Status']!='running':st.update(estado='detenido',fallos=0);return st,False
    if prueba['ok']:
        if st.get('incidente') is not None:st['recuperacion_segundos']=max(0,ahora-st.pop('incidente'))
        st.update(estado='healthy',fallos=0);return st,False
    if 'incidente' not in st:st['incidente']=ahora;st['incidentes_total']=st.get('incidentes_total',0)+1
    if prueba['causa']!='funcional' or d['State'].get('OOMKilled'):
        st.update(estado=prueba['causa'],fallos=0);return st,False
    inicio=datetime.datetime.fromisoformat(d['State']['StartedAt'][:19]+'+00:00').timestamp()
    if ahora-inicio<politica['arranque']:st.update(estado='arranque',fallos=0);return st,False
    st['fallos']+=1;st['estado']='unhealthy'
    if s not in AUTORIZADOS or not habilitado:return st,False
    if len(st['intentos'])>=politica['max_reinicios']:st['estado']='bloqueado';return st,False
    if st.get('ultimo') is not None and ahora-st['ultimo']<politica['cooldown']:st['estado']='cooldown';return st,False
    if st['fallos']<politica['fallos']:return st,False
    st.update(estado='recovering',fallos=0,ultimo=ahora)
    st['intentos']=st['intentos']+[ahora];st['reintentos_total']+=1
    return st,True

def reiniciar(s,d,activacion):
    """Revalida ID fijado y etiquetas justo antes del unico comando permitido: restart de ese ID."""
    assert s in AUTORIZADOS and identidad(d,s)
    assert activacion.get(s)==d['Id'],'ID no aprobado; requiere rearmado explicito.'
    actual=json.loads(comando(['docker','inspect',d['Id']]))[0]
    assert identidad(actual,s) and actual['Id']==d['Id'] and actual['State']['Status']=='running'
    assert not actual['State'].get('OOMKilled')
    comando(['docker','restart','--time','10',d['Id']])

def guardar(path,contenido):
    """Reemplaza atomico en directorio externo; no escribe credenciales ni cuerpos HTTP."""
    tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(contenido);os.replace(str(tmp),str(path))

def ciclo(base,ahora=None,permitir_acciones=False):
    ahora=ahora or time.time();old=json.loads((base/'estado.json').read_text()) if (base/'estado.json').exists() else {}
    activacion=json.loads((base/'activacion.json').read_text()) if (base/'activacion.json').exists() else {}
    mantenimiento=(base/'mantenimiento').exists()
    latido=base/'latido.json'
    previo=json.loads(latido.read_text()) if latido.exists() else {}
    brecha=max(0,ahora-previo.get('ultimo',ahora))
    if brecha>60:
        with (base/'incidentes.jsonl').open('a') as f:f.write(json.dumps({'timestamp':ahora,'servicio':'supervisor','estado':'brecha_observacion','segundos':brecha})+'\n')
    guardar(latido,json.dumps({'ultimo':ahora,'ultima_brecha':brecha if brecha>60 else previo.get('ultima_brecha',0)}))
    engine=True
    try:comando(['docker','info','--format','{{.ServerVersion}}']);datos=inventario();pruebas=comprobar(datos)
    except Exception:engine=False;datos={s:None for s in SERVICIOS};pruebas={s:{'ok':False,'causa':'motor_no_disponible'} for s in SERVICIOS}
    nuevo={};metricas=['tickets_supervisor_autorreparacion_activa '+str(int(bool(permitir_acciones and activacion) and not mantenimiento)),'tickets_supervisor_heartbeat_timestamp_seconds '+str(ahora),'tickets_supervisor_motor_disponible '+str(int(engine)),'tickets_supervisor_mantenimiento '+str(int(mantenimiento)),'tickets_supervisor_ultima_brecha_segundos '+str(brecha if brecha>60 else previo.get('ultima_brecha',0))]
    for s in sorted(SERVICIOS):
        st,accion=decidir(s,datos[s],pruebas[s],old.get(s,{}),ahora,bool(permitir_acciones and activacion.get(s)),mantenimiento)
        if not engine:st['estado']='motor_no_disponible'
        if accion:
            # Persiste presupuesto ANTES de llamar Docker; un fallo no genera reintentos sin limite.
            guardar(base/'estado.json',json.dumps({**old,**nuevo,s:st},indent=2))
            try:reiniciar(s,datos[s],activacion)
            except Exception:st['estado']='recuperacion_fallida'
        nuevo[s]=st
        if st.get('estado')!=old.get(s,{}).get('estado') or accion:
            with (base/'incidentes.jsonl').open('a') as f:f.write(json.dumps({'timestamp':ahora,'servicio':s,'estado':st['estado'],'reinicio_solicitado':accion})+'\n')
        metricas.append('tickets_supervisor_estado{servicio="'+s+'",estado="'+st['estado']+'"} 1')
        tags='{servicio="'+s+'"}'
        for nombre,valor in [('funcional',int(pruebas[s]['ok'])),('docker_healthy',int(datos[s] is not None and datos[s]['State'].get('Health',{}).get('Status')=='healthy')),('reinicios_docker',datos[s]['RestartCount'] if datos[s] else 0),('reinicios_solicitados_total',st['reintentos_total']),('bloqueado',int(st['estado'] in ['bloqueado','recuperacion_fallida'])),('recuperacion_segundos',st.get('recuperacion_segundos',0)),('incidentes_total',st.get('incidentes_total',0)),('incidente',int(not pruebas[s]['ok']))]:
            metricas.append('tickets_supervisor_'+nombre+tags+' '+str(valor))
        if 'wal' in pruebas[s]:metricas.append('tickets_supervisor_wal_streaming'+tags+' '+str(int(pruebas[s]['wal']>0)))
        if s=='api':
            for nombre in ['lectura','escritura']:metricas.append('tickets_supervisor_api_'+nombre+' '+str(pruebas[s].get(nombre,0)))
    guardar(base/'estado.json',json.dumps(nuevo,indent=2))
    # HELP/TYPE completos para lint Prometheus; no repetir declaraciones por serie.
    nombres=sorted({linea.split('{',1)[0].split(' ',1)[0] for linea in metricas})
    cabeceras=[]
    for nombre in nombres:
        tipo='counter' if nombre.endswith('_total') else 'gauge'
        cabeceras.extend(['# HELP '+nombre+' Evidencia funcional local del supervisor; no implica notificacion entregada.','# TYPE '+nombre+' '+tipo])
    guardar(base/'metricas'/'supervisor.prom','\n'.join(cabeceras+metricas)+'\n')
    print(json.dumps({s:st['estado'] for s,st in nuevo.items()},ensure_ascii=False))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('accion',choices=['observar','vigilar','una-vez','habilitar','suspender','mantenimiento','reanudar'])
    p.add_argument('--estado',default=str(Path.home()/'.local/state/tickets-supervision'))
    p.add_argument('--confirmar-proyecto')
    a=p.parse_args();base=Path(a.estado).expanduser();base.mkdir(parents=True,exist_ok=True,mode=0o700)
    (base/'metricas').mkdir(exist_ok=True,mode=0o755)
    # Impide dos supervisores y cambios de mantenimiento concurrentes con un ciclo.
    with (base/'supervisor.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if a.accion=='habilitar':
            assert a.confirmar_proyecto==PROYECTO,'Requiere autorizacion explicita para activar.'
            datos=inventario();assert all(datos[s] for s in AUTORIZADOS)
            guardar(base/'activacion.json',json.dumps({s:datos[s]['Id'] for s in AUTORIZADOS},indent=2));return
        if a.accion=='suspender':
            guardar(base/'activacion.json','{}');return
        if a.accion=='mantenimiento':(base/'mantenimiento').touch();return
        if a.accion=='reanudar':(base/'mantenimiento').unlink(missing_ok=True);return
        # Exclusión de vida completa: dos bucles no pueden alternarse durante el sleep.
        proceso_lock=(base/'proceso.lock').open('a')
        fcntl.flock(proceso_lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        while True:
            ciclo(base,permitir_acciones=a.accion=='vigilar')
            if a.accion=='una-vez':break
            # Libera lock al dormir para permitir mantenimiento/suspension; revalida antes del proximo ciclo.
            fcntl.flock(lock,fcntl.LOCK_UN);time.sleep(POLITICA['intervalo']);fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
if __name__=='__main__':main()
