#!/usr/bin/env python3
"""Inicia/detiene exclusivamente el observador local de Fase14; nunca arma autorreparacion."""
import argparse,json,os,signal,subprocess,time
from pathlib import Path
BASE=Path.home()/'.local/state/tickets-supervision'
SCRIPT=Path(__file__).resolve().parent/'supervisor.py'
ARCHIVO=BASE/'observador.json'
def propio(e):
    try:
        p=Path('/proc')/str(e['pid']);args=(p/'cmdline').read_bytes().split(b'\0')
        ticks=(p/'stat').read_text().rsplit(')',1)[1].split()[19]
        return str(SCRIPT).encode() in args and b'observar' in args and ticks==e['inicio_ticks']
    except (FileNotFoundError,ProcessLookupError):return False
p=argparse.ArgumentParser();p.add_argument('accion',choices=['iniciar','estado','detener']);a=p.parse_args()
e=json.loads(ARCHIVO.read_text()) if ARCHIVO.exists() else None
if a.accion=='estado':
    print(json.dumps({'activo':bool(e and propio(e)),'modo':'observar','pid':e['pid'] if e else None}));raise SystemExit(0)
if a.accion=='detener':
    assert e and propio(e),'PID no coincide: no detener procesos ajenos.'
    os.kill(e['pid'],signal.SIGTERM);print('Solo observador detenido. Contenedores intactos.');raise SystemExit(0)
assert not (e and propio(e)),'Observador ya activo; no duplicar.'
activacion=BASE/'activacion.json'
assert not activacion.exists() or not json.loads(activacion.read_text()),'Activacion inesperada: revisar sin armar nada.'
BASE.mkdir(parents=True,exist_ok=True,mode=0o700)
with (BASE/'observador.log').open('ab') as f:
    proc=subprocess.Popen(['python3','-u',str(SCRIPT),'observar'],stdin=subprocess.DEVNULL,stdout=f,stderr=f,start_new_session=True)
time.sleep(1);assert proc.poll() is None,'Observador no inicio; revisar log.'
ticks=Path('/proc/'+str(proc.pid)+'/stat').read_text().rsplit(')',1)[1].split()[19]
ARCHIVO.write_text(json.dumps({'pid':proc.pid,'script':str(SCRIPT),'modo':'observar','inicio_ticks':ticks},indent=2))
print('Observador activo PID '+str(proc.pid)+'; autorreparacion desactivada.')
