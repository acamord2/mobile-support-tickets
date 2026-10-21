#!/usr/bin/env python3
"""Prepara secretos NUEVOS fuera de Git; nunca modifica SQL ni sobrescribe un despliegue existente."""
import argparse,json,os,secrets
from pathlib import Path
RAIZ=Path(__file__).resolve().parents[2]
def preparar(destino):
    """Genera valores independientes y archivos por UID solo en un directorio externo inexistente."""
    assert os.geteuid()==0,'Requiere root para establecer propietarios de archivos nuevos.'
    destino=destino.resolve()
    assert destino.is_absolute() and destino!=RAIZ and RAIZ not in destino.parents
    assert not destino.exists(),'Destino existente: no sobrescribir ni rotar secretos.'
    assert destino.parent.is_dir(),'Preparar previamente el directorio padre aprobado.'
    os.umask(0o077);destino.mkdir(mode=0o755);(destino/'monitoring').mkdir(mode=0o755)
    os.chmod(destino,0o755);os.chmod(destino/'monitoring',0o755)
    def archivo(nombre,contenido,uid,gid):
        p=destino/nombre
        with p.open('x') as f:f.write(contenido+'\n')
        os.chown(p,uid,gid);os.chmod(p,0o400)
    escritura=secrets.token_urlsafe(48);replicacion=secrets.token_urlsafe(48)
    archivo('postgres.key',escritura,0,0)
    archivo('replicador_lectura.key',replicacion,0,0)
    archivo('replicacion.pgpass','postgres:5432:replication:replicador_lectura:'+replicacion,999,999)
    archivo('monitoring/grafana_admin.key',secrets.token_urlsafe(48),472,0)
    archivo('monitoring/postgres_monitor.key',secrets.token_urlsafe(48),65534,65534)
    archivo('secrets.json',json.dumps({'ConnectionStrings':{'DefaultConnection':'Host=postgres;Port=5432;Database=tickets_db;Username=tickets_practica;Password='+escritura},'Jwt':{'Key':secrets.token_urlsafe(48),'Issuer':'Tickets.Api','Audience':'Tickets.Mobile','ExpirationMinutes':60}},indent=2),1654,1654)
    print('Archivos externos nuevos preparados; valores omitidos. No hay roles SQL, marca de respaldo ni API desplegada. Si falla parcialmente, revisar destino sin borrar ni reintentar automáticamente.')
def main():
    """Exige opt-in explícito y ruta absoluta; el script no se ejecuta durante la documentación."""
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--destino',type=Path,required=True);parser.add_argument('--preparar',action='store_true');args=parser.parse_args()
    if not args.preparar:parser.error('Requiere --preparar para una instalación nueva autorizada.')
    assert args.destino.is_absolute(),'Ruta absoluta requerida.'
    preparar(args.destino)
if __name__=='__main__':main()
