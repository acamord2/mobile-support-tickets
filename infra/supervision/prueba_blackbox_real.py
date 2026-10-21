#!/usr/bin/env python3
"""Prueba real explicita y acotada de Blackbox; no senaliza otros procesos ni modifica datos/configuracion."""
import argparse,datetime,json,os,signal,subprocess,time
from pathlib import Path
PROYECTO='mobile-support-tickets-prueba-docker';NOMBRE=PROYECTO+'-blackbox-1'
BASE=Path('/home/econt/.local/state/tickets-supervision')
EVIDENCIA=Path('/var/lib/mobile-support-tickets/prueba_docker/prueba_blackbox')
def docker(*args):return subprocess.check_output(['docker']+list(args),text=True,timeout=15)
def inspeccionar():
    d=json.loads(docker('inspect',NOMBRE))[0]
    assert d['Name']=='/'+NOMBRE and d['Config']['Labels']['com.docker.compose.project']==PROYECTO and d['Config']['Labels']['com.docker.compose.service']=='blackbox'
    assert d['Path']=='/bin/blackbox_exporter' and d['HostConfig']['RestartPolicy']['Name']=='unless-stopped'
    return d

def emitir(d,sig):
    """Revalida ID/PID/exe y PID1 del contenedor antes de senalizar solo ese proceso host."""
    a=inspeccionar();assert a['Id']==d['Id'] and a['State']['Pid']==d['State']['Pid'] and a['State']['Status']=='running'
    pid=a['State']['Pid'];assert pid>1
    assert os.readlink('/proc/'+str(pid)+'/exe')=='/bin/blackbox_exporter'
    args=Path('/proc/'+str(pid)+'/cmdline').read_bytes().split(b'\0');assert args[0]==b'/bin/blackbox_exporter'
    status=Path('/proc/'+str(pid)+'/status').read_text();assert any(l.startswith('NSpid:') and l.split()[-1]=='1' for l in status.splitlines())
    os.kill(pid,sig)

def snapshot():
    ids=docker('ps','-q','--filter','label=com.docker.compose.project='+PROYECTO).split()
    return {d['Name']:{'id':d['Id'],'inicio':d['State']['StartedAt'],'reinicios':d['RestartCount']} for d in json.loads(docker('inspect',*ids))}

def invariantes(before):
    after=snapshot()
    for name,v in before.items():
        assert after[name]['id']==v['id'],name+' recreado inesperadamente'
        if name!='/'+NOMBRE:assert after[name]==v,name+' reiniciado inesperadamente'

def guardar(p,v):p.write_text(json.dumps(v,indent=2)+'\n')

def main():
    p=argparse.ArgumentParser();p.add_argument('accion',choices=['funcional','cooldown','terminacion']);p.add_argument('--confirmar',required=True);a=p.parse_args()
    assert a.confirmar==NOMBRE and os.geteuid()==0
    d=inspeccionar();assert d['State']['Health']['Status']=='healthy'
    assert not (BASE/'mantenimiento').exists()
    act=json.loads((BASE/'activacion.json').read_text());assert act['blackbox']==d['Id']
    supervisor=json.loads((BASE/'observador.json').read_text());cmd=Path('/proc/'+str(supervisor['pid'])+'/cmdline').read_bytes().split(b'\0');assert b'vigilar' in cmd
    inicial=json.loads((BASE/'estado.json').read_text())['blackbox'];assert inicial['estado']=='healthy'
    assert len([v for v in inicial.get('intentos',[]) if time.time()-v<3600])<3
    edad=time.time()-datetime.datetime.fromisoformat(d['State']['StartedAt'][:19]+'+00:00').timestamp()
    assert edad>120,'Gracia de arranque aun activa; no inyectar fallo'
    if a.accion=='cooldown':assert inicial.get('ultimo') and time.time()-inicial['ultimo']<230,'Fuera de ventana segura de cooldown'
    if a.accion=='terminacion':assert d['RestartCount']==0,'RestartCount inesperado, revisar antes de terminar'
    EVIDENCIA.mkdir(mode=0o700,exist_ok=True)
    carpeta=EVIDENCIA/(a.accion+'_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));carpeta.mkdir(mode=0o700)
    before=snapshot();guardar(carpeta/'baseline.json',before)
    guardar(carpeta/'blackbox_inicial.json',{'id':d['Id'],'pid':d['State']['Pid'],'inicio':d['State']['StartedAt'],'RestartCount':d['RestartCount'],'supervisor':inicial})
    t=time.time();guardar(carpeta/'inyeccion.json',{'timestamp':t,'senal':'SIGKILL' if a.accion=='terminacion' else 'SIGSTOP'})
    print('Evidencia:',carpeta,flush=True)
    fallo_activo=False;historial=[];ultimo=None;exito=False
    try:
        emitir(d,signal.SIGKILL if a.accion=='terminacion' else signal.SIGSTOP);fallo_activo=a.accion!='terminacion'
        while time.time()-t<180:
            actual=inspeccionar();st=json.loads((BASE/'estado.json').read_text())['blackbox'];invariantes(before)
            observado={'segundos':round(time.time()-t,2),'estado_supervisor':st['estado'],'fallos':st.get('fallos',0),'solicitudes':st.get('reintentos_total',0),'docker_health':actual['State'].get('Health',{}).get('Status'),'RestartCount':actual['RestartCount'],'pid':actual['State']['Pid']}
            clave=tuple(observado[k] for k in observado if k!='segundos')
            if clave!=ultimo:print(json.dumps(observado),flush=True);historial.append(observado);guardar(carpeta/'transiciones.json',historial);ultimo=clave
            delta=st.get('reintentos_total',0)-inicial.get('reintentos_total',0)
            assert delta<= (1 if a.accion=='funcional' else 0),'Mas acciones del supervisor que las autorizadas para esta variante'
            assert st['estado'] not in ['bloqueado','recuperacion_fallida'],'Recuperacion bloqueada/fallida: detener ensayo'
            if a.accion=='cooldown' and fallo_activo and st['estado']=='cooldown':
                assert actual['State']['Pid']==d['State']['Pid'];emitir(d,signal.SIGCONT);fallo_activo=False;print('Cooldown respetado: SIGCONT al PID original, sin restart.',flush=True)
            saludable=actual['State'].get('Health',{}).get('Status')=='healthy' and st['estado']=='healthy'
            if a.accion=='funcional':exito=delta==1 and actual['State']['Pid']!=d['State']['Pid'] and saludable
            elif a.accion=='cooldown':exito=not fallo_activo and saludable and any(v['estado_supervisor']=='cooldown' for v in historial)
            else:exito=actual['RestartCount']==d['RestartCount']+1 and actual['State']['Pid']!=d['State']['Pid'] and saludable
            if exito:
                resultado={'exito':True,'duracion_segundos':round(time.time()-t,2),'RestartCount_inicial':d['RestartCount'],'RestartCount_final':actual['RestartCount'],'solicitudes_supervisor_delta':delta,'ultimo_estado_supervisor':st}
                guardar(carpeta/'resultado.json',resultado);print(json.dumps(resultado),flush=True);break
            time.sleep(4)
        assert exito,'Plazo180s agotado: no continuar otros ensayos'
    finally:
        if fallo_activo:
            a2=inspeccionar()
            if a2['Id']==d['Id'] and a2['State']['Pid']==d['State']['Pid'] and a2['State']['Status']=='running':
                emitir(d,signal.SIGCONT);print('Reversion segura SIGCONT al PID suspendido original.',flush=True)
    print('Ensayo terminado; otros contenedores conservan ID/inicio/reinicios.',flush=True)
if __name__=='__main__':main()
