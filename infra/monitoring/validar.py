#!/usr/bin/env python3
"""Valida archivos e imágenes sin iniciar los servicios ni cambiar PostgreSQL."""
import ast,argparse,json,os,socket,stat,subprocess,tempfile
from pathlib import Path
import yaml
raiz=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--permisos',action='store_true')
args=parser.parse_args()
base=['docker','compose','--env-file','.env.example','-f','compose.yaml']
def modelo(cmd):return json.loads(subprocess.check_output(cmd+['config','--format','json'],cwd=raiz,text=True))
original=modelo(base)
completo=modelo(base+['-f','compose.monitoring.yaml','--profile','monitoreo'])
for nombre in ['api','postgres']:assert original['services'][nombre]==completo['services'][nombre], 'Se alteró un servicio base.'
assert 'postgres_lectura' not in completo['services']
for nombre,servicio in completo['services'].items():
 if nombre not in ['api','postgres']:
  assert not servicio.get('ports'), 'Puerto publicado en monitoreo: '+nombre
  assert servicio.get('network_mode')!='host'
  for red in servicio['networks']:assert completo['networks'][red]['internal']
# Cada scrape y datasource comparte al menos una red con su destino.
for origen,destino in [('grafana','prometheus'),('prometheus','cadvisor'),('prometheus','blackbox'),('prometheus','postgres_exporter'),('blackbox','api'),('blackbox','docker_socket_proxy'),('cadvisor','docker_socket_proxy'),('postgres_exporter','postgres')]:
 assert set(completo['services'][origen]['networks']) & set(completo['services'][destino]['networks']), 'Sin red común: '+origen+' -> '+destino
print('Monitoreo sin puertos publicados; redes internas y rutas previstas verificadas.')
for red in ['monitoreo','motor_docker']:assert completo['networks'][red]['internal']
for p in (raiz/'infra/monitoring').rglob('*.yaml'):yaml.safe_load(p.read_text())
for p in (raiz/'infra/monitoring').rglob('*.py'):ast.parse(p.read_text(),filename=str(p))
manifest=json.loads((raiz/'infra/monitoring/versiones.json').read_text())
for nombre,version in manifest.items():
 datos=json.loads(subprocess.check_output(['docker','image','inspect',version['imagen']],text=True))[0]
 assert version['digest'] in datos['RepoDigests'] and datos['Os']=='linux' and datos['Architecture']=='amd64'
 print(nombre+': imagen y digest verificados.')
datasource=yaml.safe_load((raiz/'infra/monitoring/grafana/provisioning/datasources/prometheus.yaml').read_text())['datasources'][0]
assert datasource['uid']=='prometheus_local' and datasource['url']=='http://prometheus:9090'
reglas=[];uids=set();total=0
for p in (raiz/'infra/monitoring/grafana/dashboards').glob('*.json'):
 dashboard=json.loads(p.read_text())
 assert dashboard['uid'] not in uids
 uids.add(dashboard['uid']);ids=set()
 for panel in dashboard['panels']:
  assert panel['id'] not in ids;ids.add(panel['id'])
  assert panel['datasource']['uid']==datasource['uid']
  for objetivo in panel['targets']:
   reglas.append({'record':'validacion_consulta_'+str(len(reglas)+1),'expr':objetivo['expr'].replace('$contenedor','.*')})
 total+=len(ids)
print('Grafana: '+str(len(uids))+' dashboards y '+str(total)+' paneles válidos; datasource consistente.')
montaje='type=bind,source='+str(raiz/'infra/monitoring/prometheus')+',target=/etc/prometheus,readonly'
comandos=[['docker','run','--rm','--network','none','--mount',montaje,'--entrypoint','promtool','prom/prometheus:v3.15.0','check','config','/etc/prometheus/prometheus.yaml'],['docker','run','--rm','--network','none','--mount',montaje,'--workdir','/etc/prometheus','--entrypoint','promtool','prom/prometheus:v3.15.0','test','rules','pruebas_reglas.yaml'],['docker','run','--rm','--network','none','--mount','type=bind,source='+str(raiz/'infra/monitoring/blackbox/blackbox.yaml')+',target=/etc/blackbox.yaml,readonly','quay.io/prometheus/blackbox-exporter:v0.29.0','--config.file=/etc/blackbox.yaml','--config.check'],['docker','run','--rm','--network','none','--mount','type=bind,source='+str(raiz/'infra/monitoring/docker_proxy/haproxy.cfg')+',target=/etc/haproxy/monitoring.cfg,readonly','--entrypoint','haproxy','tecnativa/docker-socket-proxy:v0.5.0','-c','-f','/etc/haproxy/monitoring.cfg']]
with tempfile.TemporaryDirectory(prefix='consultas-monitoring-') as tmp:
 p=Path(tmp)/'consultas.yaml';p.write_text(yaml.safe_dump({'groups':[{'name':'dashboards','rules':reglas}]}))
 comandos.append(['docker','run','--rm','--network','none','--mount','type=bind,source='+str(p)+',target=/tmp/consultas.yaml,readonly','--entrypoint','promtool','prom/prometheus:v3.15.0','check','rules','/tmp/consultas.yaml'])
 for comando in comandos:
  resultado=subprocess.run(comando,text=True,capture_output=True)
  if resultado.returncode:raise SystemExit('Validación fallida: '+resultado.stdout+resultado.stderr)
print('Prometheus, reglas, pruebas, PromQL, Blackbox y HAProxy: validaciones correctas.')
if args.permisos:
 if os.getuid()!=0:raise SystemExit('Usa sudo para verificar lectura como UID de cada servicio.')
 for variable,nombre,uid in [('GRAFANA_ADMIN_PASSWORD_FILE','grafana_admin.key',472),('POSTGRES_MONITOR_PASSWORD_FILE','postgres_monitor.key',65534)]:
  ruta=Path(os.environ.get(variable,'/var/lib/mobile-support-tickets/prueba_docker/monitoring/'+nombre))
  estado=ruta.stat()
  assert estado.st_uid==uid and stat.S_IMODE(estado.st_mode)==0o400
  proceso=os.fork()
  if proceso==0:
   try:
    os.setgroups([]);os.setgid(uid);os.setuid(uid)
    fd=os.open(ruta,os.O_RDONLY);os.close(fd)
    assert not os.access(ruta,os.W_OK)
    os._exit(0)
   except Exception:os._exit(1)
  assert os.waitpid(proceso,0)[1]==0
  print(nombre+': lectura real UID '+str(uid)+' confirmada; secreto no mostrado.')
print('No se iniciaron servicios ni se ejecutó el SQL de creación de usuario.')
