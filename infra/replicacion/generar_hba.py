#!/usr/bin/env python3
"""Propone HBA con la subred actual; no lo aplica ni modifica PostgreSQL."""
import ipaddress,json,subprocess
from pathlib import Path
raiz=Path(__file__).resolve().parents[2]
def leer(args): return subprocess.check_output(args,cwd=raiz,text=True)
contenedor=leer(['docker','compose','--env-file','.env.example','ps','-q','postgres']).strip()
assert contenedor, 'Falta el primario.'
info=json.loads(leer(['docker','inspect',contenedor]))[0]
subredes=[]
for nombre in info['NetworkSettings']['Networks']:
 red=json.loads(leer(['docker','network','inspect',nombre]))[0]
 if red.get('Labels',{}).get('com.docker.compose.network')=='base_datos':
  assert red['Internal'], 'La red debe ser interna.'
  subredes += [str(ipaddress.ip_network(c['Subnet'])) for c in red['IPAM']['Config'] if c.get('Subnet')]
assert subredes, 'Subred no identificada.'
print('# Bloque para colocar antes de las reglas generales, tras autorización.')
print('local all replicador_lectura reject')
print('local replication replicador_lectura reject')
for subred in subredes: print('host replication replicador_lectura '+subred+' scram-sha-256')
print('host replication replicador_lectura all reject')
print('host all replicador_lectura all reject')
