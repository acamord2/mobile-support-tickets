#!/usr/bin/env python3
"""Prueba observabilidad después del arranque autorizado; no imprime credenciales ni JWT."""
import base64,json,os,subprocess
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.parse import urlencode
from urllib.error import HTTPError

def leer(url,cabeceras=None):
 with urlopen(Request(url,headers=cabeceras or {}),timeout=20) as respuesta:return json.load(respuesta)
raiz=Path(__file__).resolve().parents[2]
def direccion(servicio,puerto):
 comando=['docker','compose','--env-file','.env.example','-f','compose.yaml','-f','compose.monitoring.yaml','--profile','monitoreo','ps','-q',servicio]
 identificador=subprocess.check_output(comando,cwd=raiz,text=True).strip()
 assert identificador, 'Servicio no iniciado: '+servicio
 datos=json.loads(subprocess.check_output(['docker','inspect',identificador],text=True))[0]
 assert not datos['HostConfig'].get('PortBindings'), 'Publicación inesperada: '+servicio
 redes=datos['NetworkSettings']['Networks']
 ip=next(v['IPAddress'] for k,v in redes.items() if k.endswith('_monitoreo'))
 return 'http://'+ip+':'+str(puerto)
def consulta(expr):
 datos=leer(prometheus+'/api/v1/query?'+urlencode({'query':expr}))
 assert datos['status']=='success'
 return datos['data']['result']
try:
 prometheus=direccion('prometheus',9090)
 grafana=direccion('grafana',3000)
 salud=leer('http://localhost:5263/api/health/database')
 assert salud['status']=='ok' and salud['database']=='connected'
 print('API /api/health/database: HTTP 200, connected.')
 for expr in ['up{job="cadvisor"}','pg_up{job="postgres"}','probe_success{job="api_disponibilidad"}','probe_success{job="docker_estado"}','probe_success{job="docker_health_postgres"}','up{job="postgres_replica"}','pg_up{job="postgres_replica"}','pg_replication_is_replica{job="postgres_replica"}']:
  resultado=consulta(expr)
  assert resultado and all(float(serie['value'][1])==1 for serie in resultado), 'Sonda o exporter no disponible: '+expr
  print('Métrica correcta: '+expr)
 for metrica in ['container_cpu_usage_seconds_total','container_memory_working_set_bytes','container_network_receive_bytes_total','container_fs_usage_bytes']:
  assert consulta('count('+metrica+'{job="cadvisor",image!=""})'), 'Falta métrica; revisar permisos cAdvisor/WSL: '+metrica
  print('Datos presentes: '+metrica)
 archivo=Path(os.environ.get('GRAFANA_ADMIN_PASSWORD_FILE','/var/lib/mobile-support-tickets/prueba_docker/monitoring/grafana_admin.key'))
 clave=archivo.read_text().strip()
 cabeceras={'Authorization':'Basic '+base64.b64encode(('admin_monitoreo:'+clave).encode()).decode()}
 assert leer(grafana+'/api/health')['database']=='ok'
 assert leer(grafana+'/api/datasources/uid/prometheus_local/health',cabeceras)['status']=='OK'
 for uid in ['docker_local','disponibilidad_local','plataforma_local','replica_local','supervision_local']:
  dashboard=leer(grafana+'/api/dashboards/uid/'+uid,cabeceras)['dashboard']
  assert dashboard['uid']==uid
  for panel in dashboard['panels']:
   for objetivo in panel['targets']:
    expresion=objetivo['expr'].replace('$contenedor','.*')
    series=consulta(expresion)
    assert series, 'Panel sin datos reales: '+panel['title']
  print('Dashboard con datos reales: '+uid+'; paneles='+str(len(dashboard['panels'])))
 assert consulta('up{job="supervision"}')[0]['value'][1]=='1'
 assert all(float(v['value'][1]) in (0,1) for v in consulta('tickets_supervisor_autorreparacion_activa')) and consulta('tickets_supervisor_autorreparacion_activa')
 assert consulta('time()-tickets_supervisor_heartbeat_timestamp_seconds') and float(consulta('time()-tickets_supervisor_heartbeat_timestamp_seconds')[0]['value'][1])<60
 print('Grafana HTTP 200: datasource operativo y cinco dashboards provisionados.')
except HTTPError as error:raise SystemExit('Fallo HTTP '+str(error.code)+'; cuerpo y credenciales omitidos.')
except AssertionError as error:raise SystemExit(str(error) or 'Comprobación fallida; detalles sensibles omitidos.')
except Exception:raise SystemExit('No se completó la prueba; no se muestran datos sensibles.')
