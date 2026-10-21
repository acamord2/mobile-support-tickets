#!/usr/bin/env python3
"""Crea únicamente el usuario de monitoreo después de autorización explícita."""
import argparse,os,subprocess
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--aplicar',action='store_true')
args=parser.parse_args()
if not args.aplicar: parser.error('Falta --aplicar; requiere autorización humana independiente.')
raiz=Path(__file__).resolve().parents[3]
assert (raiz/'.git/HEAD').read_text().strip()=='ref: refs/heads/prueba_docker'
archivo=Path(os.environ.get('POSTGRES_MONITOR_PASSWORD_FILE','/var/lib/mobile-support-tickets/prueba_docker/monitoring/postgres_monitor.key'))
clave=archivo.read_text().strip()
assert clave and len(clave)>=32
compose=['docker','compose','--env-file','.env.example']
psql=['postgres','psql','-X','-q','-v','ON_ERROR_STOP=1','-U','tickets_practica','-d','tickets_db']
entorno=os.environ.copy()
entorno['MONITOR_PASSWORD']=clave
entorno['PGOPTIONS']='-c log_statement=none -c log_duration=off -c log_min_duration_statement=-1 -c log_min_duration_sample=-1 -c log_min_error_statement=panic'
# La plantilla no incluye contraseñas. La interpolación sucede solo en memoria y con registros SQL deshabilitados en esta sesión.
sql=(raiz/'infra/monitoring/postgres/crear_usuario.sql').read_text()
sql=sql.replace('BEGIN;',chr(92)+'getenv clave_monitor MONITOR_PASSWORD'+chr(10)+"BEGIN;"+chr(10)+"SET LOCAL password_encryption='scram-sha-256';",1)
sql=sql.replace('COMMIT;',"ALTER ROLE monitor_postgres PASSWORD :'clave_monitor';"+chr(10)+'COMMIT;'+chr(10)+chr(92)+'unset clave_monitor',1)
resultado=subprocess.run(compose+['exec','-T','-e','MONITOR_PASSWORD','-e','PGOPTIONS']+psql,cwd=raiz,input=sql,text=True,env=entorno,capture_output=True)
if resultado.returncode: raise SystemExit('Creación no completada; no se muestra SQL ni información sensible. Revisar si el rol ya existe.')
print('Usuario dedicado creado con SCRAM, lectura de estadísticas y sin privilegios de aplicación.')
