#!/usr/bin/env python3
"""Gestiona solo el sshd temporal de pgAdmin; no habilita servicios ni cambia red o PostgreSQL."""
import argparse,ipaddress,json,os,signal,socket,subprocess,time
from pathlib import Path
BASE=Path('/run/tickets-pgadmin-ssh')
CONFIG=BASE/'sshd_config'
ESTADO=BASE/'estado.json'
PROYECTO='mobile-support-tickets-prueba-docker'

def proceso_propio(pid):
    """Valida PID, ejecutable y archivo exacto antes de señalizar un proceso."""
    try:
        datos=Path('/proc/'+str(pid)+'/cmdline').read_bytes().replace(b'\0',b' ').decode()
        exe=os.readlink('/proc/'+str(pid)+'/exe')
        return exe=='/usr/sbin/sshd' and str(CONFIG) in datos
    except (FileNotFoundError,ProcessLookupError):return False

def destino(servicio):
    """Resuelve solo contenedores healthy del proyecto y valida IP contra su red real."""
    nombre=PROYECTO+'-'+servicio+'-1'
    d=json.loads(subprocess.check_output(['docker','inspect',nombre],text=True))[0]
    assert d['Name']=='/'+nombre
    assert d['Config']['Labels']['com.docker.compose.project']==PROYECTO
    assert d['Config']['Labels']['com.docker.compose.service']==servicio
    assert d['State']['Health']['Status']=='healthy'
    assert not d['HostConfig'].get('PortBindings')
    red=PROYECTO+'_base_datos'
    ip=d['NetworkSettings']['Networks'][red]['IPAddress']
    redes=json.loads(subprocess.check_output(['docker','network','inspect',red],text=True))[0]
    assert redes['Internal']
    assert any(ipaddress.ip_address(ip) in ipaddress.ip_network(c['Subnet']) for c in redes['IPAM']['Config'])
    return ip

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('accion',choices=['iniciar','estado','detener'])
p.add_argument('--clave-publica',default='/mnt/c/Users/corre/.ssh/tickets_pgadmin_fase13/id_ed25519.pub')
a=p.parse_args()
assert os.geteuid()==0,'Requiere root exclusivamente para configurar y gestionar este sshd.'
estado=json.loads(ESTADO.read_text()) if ESTADO.exists() else None
if a.accion=='estado':
    print(json.dumps({'activo':bool(estado and proceso_propio(estado['pid'])),'config':str(CONFIG),'destinos':estado.get('destinos') if estado else None}))
    raise SystemExit(0)
if a.accion=='detener':
    assert estado,'No existe estado propio; no se detiene ningun proceso.'
    assert proceso_propio(estado['pid']),'PID no coincide: no enviar señales.'
    # No dejar conexiones existentes vivas al cerrar solo el listener.
    hijos=[]
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():continue
        try:
            stat=(proc/'stat').read_text().rsplit(')',1)[1].split()
            if int(stat[1])==estado['pid']:hijos.append(int(proc.name))
        except (FileNotFoundError,ProcessLookupError,PermissionError):continue
    assert not hijos,'Cerrar primero los tuneles/clientes propios; quedan conexiones SSH hijas.'
    os.kill(estado['pid'],signal.SIGTERM)
    print('SIGTERM enviado exclusivamente al sshd dedicado PID '+str(estado['pid']))
    raise SystemExit(0)
assert not (estado and proceso_propio(estado['pid'])),'Ya iniciado: no reemplazar proceso.'
with socket.socket() as s:s.bind(('127.0.0.1',2222))
ips=[destino('postgres'),destino('postgres_lectura')]
clave=Path(a.clave_publica).read_text().strip()
assert clave.startswith('ssh-ed25519 ') and len(clave.splitlines())==1
BASE.mkdir(mode=0o755,exist_ok=True)
os.chmod(BASE,0o755)
# OpenSSH 8.2 requiere su directorio de separacion de privilegios; no habilita ssh.service.
separacion=Path('/run/sshd')
if not separacion.exists():separacion.mkdir(mode=0o755)
assert separacion.stat().st_uid==0 and separacion.stat().st_mode & 0o022==0
host=BASE/'ssh_host_ed25519_key'
if not host.exists():subprocess.run(['ssh-keygen','-q','-t','ed25519','-N','','-f',str(host)],check=True)
os.chmod(host,0o600)
restricciones='restrict,port-forwarding,'+','.join('permitopen="'+ip+':5432"' for ip in ips)
(BASE/'authorized_keys').write_text(restricciones+' '+clave+'\n')
os.chmod(BASE/'authorized_keys',0o644)
config='Port 2222\nListenAddress 127.0.0.1\nAddressFamily inet\nHostKey {base}/ssh_host_ed25519_key\nPidFile {base}/sshd.pid\nAuthorizedKeysFile {base}/authorized_keys\nAllowUsers econt\nAuthenticationMethods publickey\nPubkeyAuthentication yes\nPasswordAuthentication no\nChallengeResponseAuthentication no\nPermitEmptyPasswords no\nPermitRootLogin no\nUsePAM yes\nAllowTcpForwarding local\nAllowStreamLocalForwarding no\nPermitOpen {destinos}\nGatewayPorts no\nX11Forwarding no\nAllowAgentForwarding no\nPermitTunnel no\nPermitTTY no\nPermitUserRC no\nPermitUserEnvironment no\nMaxSessions 0\nMaxAuthTries 3\nLoginGraceTime 30\nLogLevel VERBOSE\nStrictModes yes\nForceCommand /bin/false\n'
CONFIG.write_text(config.format(base=BASE,destinos=' '.join(ip+':5432' for ip in ips)))
os.chmod(CONFIG,0o600)
subprocess.run(['/usr/sbin/sshd','-t','-f',str(CONFIG)],check=True)
# Comprueba valores efectivos antes de iniciar, sin exponer claves privadas.
efectiva=subprocess.check_output(['/usr/sbin/sshd','-T','-f',str(CONFIG)],text=True)
for linea in ['listenaddress 127.0.0.1:2222','passwordauthentication no','permitrootlogin no','allowtcpforwarding local','gatewayports no','maxsessions 0','permittty no']:
    assert linea in efectiva,'Configuracion inesperada: '+linea
proceso=subprocess.Popen(['/usr/sbin/sshd','-D','-f',str(CONFIG),'-E',str(BASE/'sshd.log')],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
time.sleep(0.5)
assert proceso.poll() is None,'sshd no inicio: revisar log dedicado.'
assert proceso_propio(proceso.pid),'Identidad de proceso inesperada.'
ESTADO.write_text(json.dumps({'pid':proceso.pid,'destinos':ips,'config':str(CONFIG)},indent=2)+'\n')
os.chmod(ESTADO,0o600)
print('sshd dedicado activo en127.0.0.1:2222; PID '+str(proceso.pid)+'; destinos '+', '.join(ips))
subprocess.run(['ssh-keygen','-lf',str(host)+'.pub'],check=True)
