#!/usr/bin/env python3
"""Proxy TCP bajo demanda en Windows: loopback -> stdio WSL -> Grafana privada.

No registra HTTP, cabeceras ni credenciales. No crea listeners dentro de WSL.
Requiere Python en Windows y WSL, y acceso Docker del usuario econt.
"""
import argparse
import os
import socket
import socketserver
import subprocess
import threading

REMOTO = r"""
import json,os,socket,subprocess,sys,threading
try:
 r='/home/econt/practica/mobile-support-tickets'
 cmd=['docker','compose','--env-file','.env.example','-f','compose.yaml','-f','compose.monitoring.yaml','--profile','monitoreo','ps','-q','grafana']
 ids=subprocess.check_output(cmd,cwd=r,stderr=subprocess.DEVNULL,text=True).split()
 assert len(ids)==1
 d=json.loads(subprocess.check_output(['docker','inspect',ids[0]],stderr=subprocess.DEVNULL,text=True))[0]
 assert d['Config']['Labels']['com.docker.compose.project']=='mobile-support-tickets-prueba-docker'
 assert d['Config']['Labels']['com.docker.compose.service']=='grafana'
 assert not d['HostConfig'].get('PortBindings')
 redes=d['NetworkSettings']['Networks']
 ip=next(v['IPAddress'] for k,v in redes.items() if k.endswith('_monitoreo'))
 s=socket.create_connection((ip,3000),timeout=10)
 s.settimeout(120)
 def enviar():
  try:
   while True:
    b=os.read(0,65536)
    if not b:break
    s.sendall(b)
  except OSError:pass
  finally:
   try:s.shutdown(socket.SHUT_WR)
   except OSError:pass
 threading.Thread(target=enviar,daemon=True).start()
 while True:
  b=s.recv(65536)
  if not b:break
  sys.stdout.buffer.write(b);sys.stdout.buffer.flush()
 s.close()
except Exception:
 sys.exit(1)
"""

procesos=set()
cerrojo=threading.Lock()

class Conexion(socketserver.BaseRequestHandler):
 """Transporta bytes sin analizarlos ni guardarlos y cierra el proceso al terminar."""
 def handle(self):
  p=subprocess.Popen(['wsl.exe','-d','Ubuntu-20.04','-u','econt','--','python3','-c',REMOTO],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
  with cerrojo:procesos.add(p)
  def enviar():
   try:
    while True:
     bloque=self.request.recv(65536)
     if not bloque:break
     p.stdin.write(bloque);p.stdin.flush()
   except (OSError,ValueError):pass
   finally:
    try:p.stdin.close()
    except OSError:pass
  threading.Thread(target=enviar,daemon=True).start()
  try:
   while True:
    bloque=os.read(p.stdout.fileno(),65536)
    if not bloque:break
    self.request.sendall(bloque)
  except OSError:pass
  finally:
   try:self.request.shutdown(socket.SHUT_RDWR)
   except OSError:pass
   if p.poll() is None:p.terminate()
   p.wait()
   p.stdout.close()
   with cerrojo:procesos.discard(p)

class Servidor(socketserver.ThreadingTCPServer):
 daemon_threads=True
 block_on_close=False
 allow_reuse_address=False
 def server_bind(self):
  self.socket.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
  super().server_bind()

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--puerto',type=int,default=13000,choices=range(1024,65536),metavar='1024..65535')
 args=parser.parse_args()
 if os.name!='nt':parser.error('Ejecutar en Windows; no iniciar en WSL.')
 with Servidor(('127.0.0.1',args.puerto),Conexion) as servidor:
  print('Acceso temporal: http://127.0.0.1:'+str(args.puerto)+' ; Ctrl+C para cerrar.')
  try:servidor.serve_forever()
  except KeyboardInterrupt:pass
  finally:
   with cerrojo:
    for proceso in list(procesos):
     if proceso.poll() is None:proceso.terminate()
