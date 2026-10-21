#!/usr/bin/env python3
"""Ensaya restauración únicamente en un contenedor efímero aislado, previa autorización."""
import argparse,hashlib,json,secrets,subprocess,time
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--respaldo',type=Path,required=True)
parser.add_argument('--aplicar',action='store_true')
args=parser.parse_args()
if not args.aplicar:parser.error('Requiere --aplicar y autorización; no se inició ningún contenedor.')
respaldo=args.respaldo.resolve()
for nombre in ['tickets_db.dump','globales.sql','SHA256SUMS']:
 assert (respaldo/nombre).is_file() and (respaldo/nombre).stat().st_size>0
for linea in (respaldo/'SHA256SUMS').read_text().splitlines():
 huella,nombre=linea.split(None,1)
 archivo=(respaldo/nombre.strip()).resolve()
 assert respaldo in archivo.parents
 assert hashlib.sha256(archivo.read_bytes()).hexdigest()==huella
imagen='postgres@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3'
contenedor=None
nombre='tickets-ensayo-respaldo-'+secrets.token_hex(5)
def ejecutar(comando,entrada=None):
 resultado=subprocess.run(comando,input=entrada,capture_output=True)
 if resultado.returncode:raise RuntimeError('Ensayo fallido; detalles SQL y credenciales omitidos.')
 return resultado.stdout
try:
 contenedor=ejecutar(['docker','run','-d','--network','none','--log-driver','none','--name',nombre,'--label','practica.validacion=respaldo','--tmpfs','/var/lib/postgresql/data:rw,nosuid,size=512m','-e','POSTGRES_HOST_AUTH_METHOD=trust',imagen,'postgres','-c','shared_buffers=32MB']).decode().strip()
 for intento in range(60):
  estado=subprocess.run(['docker','exec',contenedor,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True)
  if estado.returncode==0:break
  time.sleep(1)
 else:raise RuntimeError('El contenedor aislado no estuvo listo a tiempo.')
 # Solo el contenedor cuyo ID acabamos de crear puede recibir SQL del ensayo.
 ejecutar(['docker','exec','-i',contenedor,'psql','-X','-q','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres'],(respaldo/'globales.sql').read_bytes())
 ejecutar(['docker','exec',contenedor,'createdb','-U','postgres','-O','tickets_practica','tickets_db'])
 ejecutar(['docker','exec','-i',contenedor,'pg_restore','--exit-on-error','-U','postgres','-d','tickets_db'],(respaldo/'tickets_db.dump').read_bytes())
 consulta=("SELECT (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'),(SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'),(SELECT count(*) FROM information_schema.views WHERE table_schema='public'),(SELECT count(*) FROM public."+chr(34)+"Roles"+chr(34)+"),(SELECT count(*) FROM public."+chr(34)+"Users"+chr(34)+");").encode()
 resultado=ejecutar(['docker','exec','-i',contenedor,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','tickets_practica','-d','tickets_db'],consulta).decode().strip()
 assert resultado=='8|1|1|4|5', 'Conteos restaurados inesperados.'
 print('Ensayo aislado correcto: 8 tablas, 1 función, 1 vista, 4 roles de aplicación y 5 usuarios. Sin mostrar contenido sensible.')
 print('Dump restaurado y comprobado; ninguna instancia existente recibió SQL. No se habilita replicación.')
except Exception:
 raise SystemExit('Ensayo no confirmado; detalles sensibles omitidos. No considerar el respaldo restaurable.')
finally:
 if contenedor:
  inspeccion=json.loads(ejecutar(['docker','inspect',contenedor]))[0]
  assert inspeccion['Name']=='/'+nombre and inspeccion['Config']['Labels'].get('practica.validacion')=='respaldo'
  ejecutar(['docker','rm','-f',contenedor])
