#!/usr/bin/env python3
"""Crea solo consultor_api y un archivo externo candidato; no modifica secretos activos ni despliega API."""
import argparse,json,os,secrets,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--aplicar',action='store_true');a=p.parse_args()
if not a.aplicar:p.error('Requiere autorización y --aplicar.')
r=Path(__file__).resolve().parents[2]
assert (r/'.git/HEAD').read_text().strip()=='ref: refs/heads/prueba_docker'
ext=Path('/var/lib/mobile-support-tickets/prueba_docker')
archivo=ext/'secrets-lectura-escritura.json';clavearchivo=ext/'consultor_api.key'
assert not archivo.exists() and not clavearchivo.exists(), 'No se sobrescriben credenciales existentes.'
c=['docker','compose','--env-file','.env.example','exec','-T']
def consulta(sql,entorno=None):
 args=c+(['-e','CONSULTOR_PASSWORD','-e','PGOPTIONS'] if entorno else [])+['postgres','psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','tickets_practica','-d','tickets_db']
 p=subprocess.run(args,cwd=r,input=sql,text=True,capture_output=True,env=entorno)
 if p.returncode:raise SystemExit('Fallo SQL; detener. Se omiten detalles sensibles.')
 return p.stdout.strip()
assert consulta("SELECT count(*) FROM pg_roles WHERE rolname='consultor_api';")=='0'
# Rechazar privilegios PUBLIC de escritura antes de crear un rol que pudiera heredarlos.
assert consulta("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a WHERE n.nspname='public' AND a.grantee=0 AND a.privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE');")=='0'
base=json.loads((ext/'secrets.json').read_text())
# Solo se usan parámetros conocidos, sin imprimir ni alterar la conexión activa.
clave=secrets.token_urlsafe(48)
base.setdefault('ConnectionStrings',{})
legacy=base.get('ConnectionStrings:DefaultConnection') or base['ConnectionStrings'].get('DefaultConnection')
assert legacy, 'Formato de conexión activa no reconocido; detener sin cambios.'
base['ConnectionStrings']['Escritura']=legacy
base['ConnectionStrings']['Lectura']='Host=postgres_lectura;Port=5432;Database=tickets_db;Username=consultor_api;Password='+clave
base.setdefault('SecretsApi',{})['LecturasEnPrimario']=False
base['SecretsApi']['PermitirFallbackLectura']=True
os.umask(0o077)
clavearchivo.write_text(clave+'\n');os.chown(clavearchivo,1654,1654);os.chmod(clavearchivo,0o400)
entorno=os.environ.copy();entorno['CONSULTOR_PASSWORD']=clave
entorno['PGOPTIONS']='-c log_statement=none -c log_duration=off -c log_min_duration_statement=-1 -c log_min_duration_sample=-1 -c log_min_error_statement=panic'
sql=(r/'infra/lectura/crear_consultor.sql').read_text().replace('BEGIN;',chr(92)+"getenv clave_consulta CONSULTOR_PASSWORD\nBEGIN;\nSET LOCAL password_encryption='scram-sha-256';",1)
sql=sql.replace('COMMIT;',"ALTER ROLE consultor_api PASSWORD :'clave_consulta';\nCOMMIT;\n"+chr(92)+'unset clave_consulta')
consulta(sql,entorno)
archivo.write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n');os.chown(archivo,1654,1654);os.chmod(archivo,0o400)
print('consultor_api creado con SCRAM y SELECT por columna. Candidato externo preparado; secretos activos intactos. API no desplegada.')
