#!/usr/bin/env python3
"""Valida documentación local, diagramas y fuentes sin arrancar servicios ni modificar datos."""
import ast,json,re,subprocess,xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote
import yaml
RAIZ=Path(__file__).resolve().parents[2]
def validar():
    """Comprueba enlaces relativos fuera de bloques de código y referencias del draw.io editable."""
    docs=RAIZ/'docs/infraestructura'
    assert len(list(docs.glob('[0-9][0-9]-*.md')))==10
    errores=[]
    for p in [RAIZ/'README.md']+list(docs.rglob('*.md')):
        texto=re.sub(r'```.*?```','',p.read_text(),flags=re.S)
        for url in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)',texto):
            url=unquote(url.strip().strip('<>')).split('#')[0]
            if not url or re.match(r'[A-Za-z][A-Za-z0-9+.-]*:',url):continue
            if not (p.parent/url).exists():errores.append(str(p.relative_to(RAIZ))+': '+url)
    assert not errores,'Enlaces inexistentes: '+str(errores)
    arbol=ET.parse(docs/'arquitectura.drawio'); assert arbol.getroot().tag=='mxfile'
    celdas=arbol.findall('.//mxCell');ids=[x.get('id') for x in celdas]; assert len(ids)==len(set(ids))
    for celda in celdas:
        for k in ['parent','source','target']:
            if celda.get(k):assert celda.get(k) in ids
    inv=json.loads((docs/'inventario-verificado.json').read_text());assert len(inv['contenedores'])==11
    for p in (RAIZ/'infra').rglob('*.py'):ast.parse(p.read_text(),filename=str(p))
    for p in (RAIZ/'infra').rglob('*.json'):json.loads(p.read_text())
    for p in (RAIZ/'infra').rglob('*.yaml'):yaml.safe_load(p.read_text())
    for p in (RAIZ/'infra').rglob('*.sh'):subprocess.run(['sh','-n',str(p)],check=True)
    for p in (docs/'plantillas').glob('*.json.example'):json.loads(p.read_text())
    subprocess.run(['sh',str(RAIZ/'infra/operacion/compose_proyecto.sh'),'config','--quiet'],check=True)
    print('10manuales; enlaces relativos, XMLdrawio/referencias, JSON, YAML, ASTPython, shell y Compose válidos.')
if __name__=='__main__':validar()
