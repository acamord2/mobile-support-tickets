#!/usr/bin/env python3
"""Comprueba precondiciones sin Docker ni escrituras; nunca arma ni restablece estado."""
import json,os,grp,pwd
from pathlib import Path
BASE=Path('/home/econt/.local/state/tickets-supervision')
SCRIPT=Path('/home/econt/practica/mobile-support-tickets/infra/supervision/supervisor.py')
AUTORIZADOS={'api','grafana','blackbox','postgres_exporter','postgres_exporter_lectura'}

def validar_estado(base):
    """Exige evidencia existente y valida estructura sin modificar presupuesto/mantenimiento."""
    for nombre in ['estado.json','activacion.json','politica.json']:
        archivo=base/nombre if nombre!='politica.json' else SCRIPT.parent/nombre
        if not archivo.is_file():raise RuntimeError('Falta archivo persistente: '+nombre)
    estado=json.loads((base/'estado.json').read_text())
    assert isinstance(estado,dict) and AUTORIZADOS<=set(estado),'Estado incompleto; no inicializar automaticamente.'
    for v in estado.values():
        assert isinstance(v,dict) and isinstance(v.get('intentos'),list)
        assert isinstance(v.get('reintentos_total'),int) and v['reintentos_total']>=0
        assert all(isinstance(t,(float,int)) for t in v['intentos'])
    activacion=json.loads((base/'activacion.json').read_text())
    assert isinstance(activacion,dict) and set(activacion)<=AUTORIZADOS
    assert all(isinstance(v,str) and len(v)==64 and all(c in '0123456789abcdef' for c in v) for v in activacion.values())
    # {} significa suspension deliberada; se acepta sin rearmar IDs.
    return estado,activacion

def procesos(proc=Path('/proc')):
    """Busca instancias exactas, sin pgrep amplio ni enviar senales."""
    encontrados=[]
    for p in proc.iterdir():
        if not p.name.isdigit():continue
        try:args=(p/'cmdline').read_bytes().split(b'\0')
        except (FileNotFoundError,ProcessLookupError,PermissionError):continue
        if str(SCRIPT).encode() in args and any(a in args for a in [b'observar',b'vigilar']):encontrados.append(int(p.name))
    return encontrados

def main():
    cuenta=pwd.getpwnam('econt');assert os.geteuid()==cuenta.pw_uid and os.geteuid()!=0,'Debe ejecutarse como econt.'
    assert grp.getgrnam('docker').gr_gid in os.getgroups(),'Falta pertenencia Docker existente; no agregar permisos aqui.'
    assert BASE.stat().st_uid==cuenta.pw_uid and os.access(BASE,os.W_OK|os.X_OK)
    validar_estado(BASE)
    activos=procesos()
    if activos:raise SystemExit('Inicio rechazado: existe supervisor manual/servicio PID '+','.join(map(str,activos)))
    print('Precondiciones correctas; estado existente conservado. Docker puede estar caido: no se modifica ni se inicia.')
if __name__=='__main__':main()
