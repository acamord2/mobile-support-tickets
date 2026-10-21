#!/usr/bin/env python3
"""Comprueba endpoints existentes sin insertar datos; credenciales de práctica y JWT permanecen en memoria."""
import argparse,json,secrets,subprocess
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.error import HTTPError
p=argparse.ArgumentParser();p.add_argument('--url',default='http://localhost:5263');a=p.parse_args()
r=Path(__file__).resolve().parents[2]
sql="SELECT json_build_object('username',\"Username\") FROM public.\"Users\" WHERE \"RoleId\"=2 AND \"IsActive\"=1 AND \"Username\" ~ '^[0-9]+$' LIMIT 1;"
z=subprocess.run(['docker','compose','--env-file','.env.example','exec','-T','postgres','psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','tickets_practica','-d','tickets_db'],cwd=r,input=sql,text=True,capture_output=True)
assert z.returncode==0 and z.stdout.strip(), 'Falta cuenta técnica de práctica; no crear datos automáticamente.'
u=json.loads(z.stdout)['username']
def pedir(ruta,datos=None,token=None,cabeceras=None):
 h={'Accept':'application/json'};h.update(cabeceras or {})
 if token:h['Authorization']='Bearer '+token
 cuerpo=None
 if datos is not None:cuerpo=json.dumps(datos).encode();h['Content-Type']='application/json'
 try:
  with urlopen(Request(a.url+ruta,data=cuerpo,headers=h),timeout=14) as res:return res.status,json.load(res),res.headers
 except HTTPError as e:return e.code,None,e.headers
codigo,datos,_=pedir('/api/health/database');assert codigo==200 and datos['database']=='connected';print('Health:200 connected.')
codigo,datos,_=pedir('/api/health/disponibilidad');assert codigo==200 and datos['lectura'] and datos['escritura'];print('Disponibilidad:200 completo.')
assert pedir('/api/tickets')[0]==401
assert pedir('/api/auth/login',{'username':'inexistente-'+secrets.token_hex(5),'password':secrets.token_urlsafe(32)})[0]==401
# Las cuentas numéricas existentes fueron autorizadas con contraseña igual al usuario; no imprimirlas.
codigo,datos,_=pedir('/api/auth/login',{'username':u,'password':u});assert codigo==200,'Login de práctica no válido; detener sin mostrar credenciales.'
token=datos['token'];print('Login200; anónimo/credenciales incorrectas401; JWT solo en memoria.')
assert pedir('/api/auth/me',token=token)[0]==200
for ruta in ['/api/branches','/api/tickets','/api/tickets/1/events','/api/ticket-status-requests?pendingOnly=false']:
 codigo,datos,h=pedir(ruta,token=token);assert codigo==200 and isinstance(datos,list)
 assert h.get('X-Destino-Lectura')=='secundaria', 'Consulta no dirigida a standby.'
 print(ruta.split('?')[0]+':200 destino=secundaria.')
assert pedir('/api/technicians',token=token)[0]==403
codigo,datos,h=pedir('/api/tickets',token=token,cabeceras={'X-Consistencia':'inmediata'});assert codigo==200 and h.get('X-Destino-Lectura')=='primaria'
print('Me200; técnicos403 para rol técnico; lectura inmediata200 destino=primaria. Sin escrituras de negocio.')

# Comprobar también la quinta lectura con una cuenta coordinadora existente.
sql=sql.replace("=2 AND", "=3 AND")
z=subprocess.run(['docker','compose','--env-file','.env.example','exec','-T','postgres','psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','tickets_practica','-d','tickets_db'],cwd=r,input=sql,text=True,capture_output=True)
assert z.returncode==0 and z.stdout.strip()
u=json.loads(z.stdout)['username']
codigo,datos,_=pedir('/api/auth/login',{'username':u,'password':u});assert codigo==200
token=datos['token'];codigo,datos,h=pedir('/api/technicians',token=token)
assert codigo==200 and h.get('X-Destino-Lectura')=='secundaria'
print('Técnicos:200 destino=secundaria con coordinación; cinco lecturas verificadas.')
