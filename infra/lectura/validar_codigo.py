#!/usr/bin/env python3
"""Compila y prueba en SDK temporal; no reemplaza imágenes ni reinicia servicios del proyecto."""
import argparse,json,secrets,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--conexiones-reales',action='store_true');a=p.parse_args()
r=Path(__file__).resolve().parents[2]
nombre='tickets-validacion-122-'+secrets.token_hex(4)
args=['docker','run','-d','--network','bridge','--name',nombre,'--label','practica.validacion=lectura122','--mount','type=bind,source='+str(r)+',target=/fuente,readonly']
if a.conexiones_reales:
 args+=['--mount','type=bind,source=/var/lib/mobile-support-tickets/prueba_docker/secrets-lectura-escritura.json,target=/config-prueba.json,readonly','-e','PRUEBA_CONEXIONES_FILE=/config-prueba.json']
args+=['--entrypoint','sleep','mcr.microsoft.com/dotnet/sdk:10.0','600']
i=subprocess.check_output(args,text=True).strip()
def ejecutar(cmd):
 p=subprocess.run(cmd,text=True,capture_output=True)
 print(p.stdout,end='');print(p.stderr,end='')
 if p.returncode:raise SystemExit(p.returncode)
try:
 ejecutar(['docker','exec',i,'sh','-c','mkdir -p /tmp/verificacion && cd /fuente && tar --exclude=bin --exclude=obj -cf - api tests/api | tar -xf - -C /tmp/verificacion && cd /tmp/verificacion && dotnet run --project tests/api/PruebasApi.csproj -- --configuracion && dotnet run --no-build --project tests/api/PruebasApi.csproj -- --separacion && dotnet run --no-build --project tests/api/PruebasApi.csproj'])
 if a.conexiones_reales:
  ejecutar(['docker','network','connect','mobile-support-tickets-prueba-docker_base_datos',i])
  ejecutar(['docker','exec','-w','/tmp/verificacion',i,'dotnet','run','--no-build','--project','tests/api/PruebasApi.csproj','--','--conexiones-lectura'])
finally:
 d=json.loads(subprocess.check_output(['docker','inspect',i],text=True))[0]
 assert d['Name']=='/'+nombre and d['Config']['Labels'].get('practica.validacion')=='lectura122' and not d['Config']['Labels'].get('com.docker.compose.project')
 subprocess.run(['docker','rm','-f',i],check=True,stdout=subprocess.DEVNULL)
