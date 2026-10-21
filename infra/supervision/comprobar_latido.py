#!/usr/bin/env python3
"""Comprueba evidencia del supervisor sin Docker/Prometheus; util tambien tras su recuperacion."""
import argparse,json,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--estado',default=str(Path.home()/'.local/state/tickets-supervision'));a=p.parse_args()
f=Path(a.estado)/'latido.json'
if not f.exists():raise SystemExit('Sin evidencia de supervisor: no afirmar supervision activa.')
v=json.loads(f.read_text());edad=max(0,time.time()-v['ultimo'])
print('Edad del latido: %.1f s; ultima brecha registrada: %.1f s'%(edad,v.get('ultima_brecha',0)))
if edad>60:raise SystemExit('Supervisor sin latido reciente; comprobar WSL, proceso y disco.')
