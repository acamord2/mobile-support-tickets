#!/usr/bin/env python3
"""Gestiona un solo proceso observar/vigilar con identidad verificada y sin armar implicitamente."""
import argparse,json,os,signal,subprocess,time
from pathlib import Path
BASE=Path.home()/'.local/state/tickets-supervision';SCRIPT=Path(__file__).resolve().parent/'supervisor.py';ARCHIVO=BASE/'observador.json'
def propio(e):
    try:
        p=Path('/proc')/str(e['pid']);args=(p/'cmdline').read_bytes().split(b'\0')
        ticks=(p/'stat').read_text().rsplit(')',1)[1].split()[19]
        return str(SCRIPT).encode() in args and e['modo'].encode() in args and ticks==e['inicio_ticks']
    except (FileNotFoundError,ProcessLookupError):return False
p=argparse.ArgumentParser();p.add_argument('accion',choices=['iniciar','estado','detener']);p.add_argument('--modo',choices=['observar','vigilar'],default='observar');a=p.parse_args()
e=json.loads(ARCHIVO.read_text()) if ARCHIVO.exists() else None
if a.accion=='estado':
    print(json.dumps({'activo':bool(e and propio(e)),'modo':e.get('modo') if e else None,'pid':e['pid'] if e else None}));raise SystemExit(0)
if a.accion=='detener':
    assert e and propio(e),'PID no coincide: no detener procesos ajenos.'
    os.kill(e['pid'],signal.SIGTERM)
    for i in range(30):
        if not propio(e):break
        time.sleep(.1)
    assert not propio(e),'Proceso no termino; revisar sin matar procesos ajenos.'
    print('Solo proceso supervisor propio detenido.');raise SystemExit(0)
assert not (e and propio(e)),'Ya existe proceso propio; detener antes de cambiar modo.'
for pdir in Path('/proc').iterdir():
    if not pdir.name.isdigit():continue
    try:args=(pdir/'cmdline').read_bytes().split(b'\0')
    except (FileNotFoundError,PermissionError,ProcessLookupError):continue
    assert not (str(SCRIPT).encode() in args and any(m in args for m in [b'observar',b'vigilar'])),'Otro supervisor existe; no duplicar.'
activacion=BASE/'activacion.json'
if a.modo=='vigilar':
    from supervisor import AUTORIZADOS,inventario
    assert activacion.exists(),'Falta armando explicito por operador.'
    ids=json.loads(activacion.read_text());datos=inventario()
    assert set(ids)==AUTORIZADOS and all(datos[s] and datos[s]['Id']==ids[s] for s in AUTORIZADOS),'IDs/servicios no corresponden a activacion.'
BASE.mkdir(parents=True,exist_ok=True,mode=0o700)
with (BASE/'observador.log').open('ab') as f:
    proc=subprocess.Popen(['python3','-u',str(SCRIPT),a.modo],stdin=subprocess.DEVNULL,stdout=f,stderr=f,start_new_session=True)
time.sleep(1);assert proc.poll() is None,'Supervisor no inicio; revisar log.'
ticks=Path('/proc/'+str(proc.pid)+'/stat').read_text().rsplit(')',1)[1].split()[19]
ARCHIVO.write_text(json.dumps({'pid':proc.pid,'script':str(SCRIPT),'modo':a.modo,'inicio_ticks':ticks},indent=2))
print('Proceso propio activo PID '+str(proc.pid)+' modo '+a.modo)
