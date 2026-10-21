#!/usr/bin/env python3
"""Comprueba ACL reales por columna con SET ROLE en cada nodo, sin conceder acceso HBA ni modificar datos."""
from pathlib import Path
import json,subprocess,os,time
r=Path(__file__).resolve().parents[2]
columnas=json.loads((r/'infra/lectura/columnas_consulta.json').read_text())
c=['docker','compose','--env-file','.env.example','-f','compose.yaml','-f','compose.replica.yaml','--profile','replicacion','exec','-T']
def q(nodo,sql):
 p=subprocess.run(c+[nodo,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','tickets_practica','-d','tickets_db'],cwd=r,input=sql,text=True,capture_output=True)
 if p.returncode:raise SystemExit('Error al comprobar permisos; salida sensible omitida.')
 return p.stdout.strip()
for nodo in ['postgres','postgres_lectura']:
 assert q(nodo,"SELECT count(*) FROM pg_roles WHERE rolname='consultor_api' AND rolcanlogin AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication AND NOT rolbypassrls;")=='1'
 assert q(nodo,"SELECT count(*) FROM pg_auth_members WHERE member=(SELECT oid FROM pg_roles WHERE rolname='consultor_api');")=='0'
 consultas="""SET ROLE consultor_api;
 SELECT json_agg(row_to_json(x)) FROM (
 SELECT c.relname tabla,a.attname columna,has_column_privilege(current_user,c.oid,a.attnum,'SELECT') lee,
 has_column_privilege(current_user,c.oid,a.attnum,'INSERT') inserta,has_column_privilege(current_user,c.oid,a.attnum,'UPDATE') actualiza,
 has_table_privilege(current_user,c.oid,'DELETE') borra,has_table_privilege(current_user,c.oid,'TRUNCATE') trunca
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid
 WHERE n.nspname='public' AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum) x;
 """
 filas=json.loads(q(nodo,consultas))
 for f in filas:
  assert f['lee']==(f['columna'] in columnas.get(f['tabla'],[])), 'SELECT fuera del inventario autorizado.'
  assert not any(f[k] for k in ['inserta','actualiza','borra','trunca'])
 assert q(nodo,"SET ROLE consultor_api; SELECT has_database_privilege(current_user,'tickets_db','CONNECT') AND NOT has_database_privilege(current_user,'tickets_db','CREATE') AND NOT has_schema_privilege(current_user,'public','CREATE');")=='t'
 for tabla,cols in columnas.items():
  q(nodo,'SET ROLE consultor_api; SELECT '+','.join('"'+s+'"' for s in cols)+' FROM public."'+tabla+'" LIMIT 0;')
 print(nodo+': todas las columnas cotejadas, PasswordHash/Roles excluidos; sin escritura ni CREATE en public/tickets_db. SELECT reales correctos con SET ROLE.')
 print(nodo+' TEMP heredado de PUBLIC: '+q(nodo,"SET ROLE consultor_api; SELECT has_database_privilege(current_user,'tickets_db','TEMP');"))
print('No se modificaron privilegios PUBLIC. SET ROLE verifica ACL, no autenticación TCP de standby.')
