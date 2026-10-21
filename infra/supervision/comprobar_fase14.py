#!/usr/bin/env python3
"""Valida Fase14 en lectura: targets, reglas, paneles y ausencia de autorreparacion; no muestra secretos."""
import argparse,base64,json,subprocess,time,urllib.request,urllib.parse
from pathlib import Path

def host(n,port):
    d=json.loads(subprocess.check_output(['docker','inspect','mobile-support-tickets-prueba-docker-'+n+'-1'],text=True))[0]
    ip=next(v['IPAddress'] for k,v in d['NetworkSettings']['Networks'].items() if k.endswith('_monitoreo'))
    return 'http://'+ip+':'+str(port)
def get(url,h=None):
    return json.load(urllib.request.urlopen(urllib.request.Request(url,headers=h or {}),timeout=5))
parser=argparse.ArgumentParser();parser.add_argument('--autorreparacion',type=int,choices=[0,1],default=0);args=parser.parse_args()
prom=host('prometheus',9090)
def query(e):return get(prom+'/api/v1/query?'+urllib.parse.urlencode({'query':e}))['data']['result']
for i in range(12):
    targets=get(prom+'/api/v1/targets')['data']['activeTargets']
    if len(targets)==10 and all(t['health']=='up' for t in targets) and query('tickets_supervisor_heartbeat_timestamp_seconds'):break
    if i==11:raise SystemExit('Targets o metricas no operativos; revisar sin reiniciar servicios.')
    time.sleep(3)
print('10/10 targets UP; supervision con muestras.')
assert float(query('prometheus_config_last_reload_successful')[0]['value'][1])==1
rules=get(prom+'/api/v1/rules')['data']['groups'];names=[v['name'] for g in rules for v in g['rules']]
assert len(names)==14
print('14 reglas cargadas:',', '.join(names))
datos=query('tickets_supervisor_autorreparacion_activa');assert datos and all(float(v['value'][1])==args.autorreparacion for v in datos)
for e in ['tickets_supervisor_funcional','tickets_supervisor_wal_streaming']:
    datos=query(e);assert datos and all(float(v['value'][1])==1 for v in datos)
assert float(query('time()-tickets_supervisor_heartbeat_timestamp_seconds')[0]['value'][1])<60
key=Path('/var/lib/mobile-support-tickets/prueba_docker/monitoring/grafana_admin.key').read_text().strip()
h={'Authorization':'Basic '+base64.b64encode(('admin_monitoreo:'+key).encode()).decode()}
graf=host('grafana',3000)
assert get(graf+'/api/health')['database']=='ok'
assert get(graf+'/api/datasources/uid/prometheus_local/health',h)['status']=='OK'
total=0
for uid in ['docker_local','disponibilidad_local','plataforma_local','replica_local','supervision_local']:
    d=get(graf+'/api/dashboards/uid/'+uid,h)['dashboard']
    for panel in d['panels']:
        for target in panel['targets']:
            assert query(target['expr'].replace('$contenedor','.*')),'No data: '+uid+'/'+panel['title']
    total+=len(d['panels']);print(uid+': '+str(len(d['panels']))+' paneles con datos')
assert total==50
print('Autorreparacion esperada='+str(args.autorreparacion)+', WAL streaming=1; datasource correcto.')
