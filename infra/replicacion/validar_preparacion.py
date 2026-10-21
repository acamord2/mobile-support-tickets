#!/usr/bin/env python3
"""Comprueba preparación sin aplicar SQL, crear slots ni iniciar servicios."""
import argparse,hashlib,json,os,stat,subprocess
from pathlib import Path
raiz=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--permisos-y-respaldo',action='store_true')
args=parser.parse_args()
base=['docker','compose','--env-file','.env.example','-f','compose.yaml']
def modelo(comando): return json.loads(subprocess.check_output(comando+['config','--format','json'],cwd=raiz,text=True))
original=modelo(base)
combinado=modelo(base+['-f','compose.replica.yaml','--profile','replicacion'])
for nombre in ('api','postgres'):
 assert original['services'][nombre]==combinado['services'][nombre], 'Servicio base alterado.'
replica=combinado['services']['postgres_lectura']
assert not replica.get('ports') and set(replica['networks'])=={'base_datos'}
assert all(v.get('source')!='datos_postgres' for v in replica['volumes'])
identificador=subprocess.check_output(['docker','compose','--env-file','.env.example','ps','-q','postgres'],cwd=raiz,text=True).strip()
primario=json.loads(subprocess.check_output(['docker','inspect',identificador],text=True))[0]
imagen=json.loads(subprocess.check_output(['docker','image','inspect',replica['image']],text=True))[0]
assert primario['Image']==imagen['Id'], 'Digest distinto al del primario.'
print('Compose válido: primario y API intactos; imagen idéntica, volumen separado y red privada sin puertos.')
if args.permisos_y_respaldo:
 pgpass=Path(os.environ.get('REPLICA_PGPASS_FILE','/var/lib/mobile-support-tickets/prueba_docker/replicacion.pgpass'))
 marca=Path(os.environ.get('REPLICA_RESPALDO_OK','/var/lib/mobile-support-tickets/prueba_docker/respaldo-verificado.json'))
 estado=pgpass.stat()
 assert estado.st_uid==999 and estado.st_gid==999 and stat.S_IMODE(estado.st_mode) in (0o400,0o600), 'Permisos pgpass incorrectos.'
 control=json.loads(marca.read_text())
 assert control.get('restauracion_verificada') is True, 'Falta ensayo de restauración.'
 respaldo=Path(control['respaldo_dir']).resolve()
 assert raiz not in respaldo.parents and respaldo!=raiz
 dump=respaldo/'tickets_db.dump'
 assert dump.stat().st_size>0
 assert hashlib.sha256(dump.read_bytes()).hexdigest()==control['sha256_dump'], 'Respaldo distinto al verificado.'
 assert all((respaldo/n).is_file() and (respaldo/n).stat().st_size>0 for n in ['globales.sql','postgresql.conf','pg_hba.conf','control_cluster.txt','SHA256SUMS'])
 if os.getuid()==0:
  proceso=os.fork()
  if proceso==0:
   try:
    os.setgroups([]);os.setgid(999);os.setuid(999)
    descriptor=os.open(pgpass,os.O_RDONLY);os.close(descriptor)
    assert not os.access(pgpass,os.W_OK) or stat.S_IMODE(estado.st_mode)==0o600
    os._exit(0)
   except Exception: os._exit(1)
  assert os.waitpid(proceso,0)[1]==0, 'UID 999 no puede leer pgpass.'
 else:
  raise SystemExit('Ejecuta esta comprobación con sudo para probar lectura efectiva como UID 999.')
 print('Permisos UID 999 y respaldo autorizado comprobados, sin mostrar contenidos.')
