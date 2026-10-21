"""Valida guardas de instalacion con fixtures; no utiliza systemctl ni senaliza procesos."""
import json,tempfile,unittest
from pathlib import Path
import verificar_unidad as v
class Unidad(unittest.TestCase):
    def preparar(self,p):
        estado={s:{'intentos':[1792607490.0],'reintentos_total':1} for s in v.AUTORIZADOS}
        (p/'estado.json').write_text(json.dumps(estado));(p/'activacion.json').write_text(json.dumps({s:'a'*64 for s in v.AUTORIZADOS}));return estado
    def test_no_reinicia_presupuesto(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t);original=self.preparar(p);before=(p/'estado.json').read_bytes();estado,_=v.validar_estado(p)
            self.assertEqual(estado,original);self.assertEqual(before,(p/'estado.json').read_bytes())
    def test_suspension_vacia_se_conserva(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t);self.preparar(p);(p/'activacion.json').write_text('{}');self.assertEqual(v.validar_estado(p)[1],{})
    def test_estado_ausente_falla_cerrado(self):
        with tempfile.TemporaryDirectory() as t:
            with self.assertRaises(RuntimeError):v.validar_estado(Path(t))
    def test_rol_no_permitido_falla(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t);self.preparar(p);(p/'activacion.json').write_text('{"postgres":"'+('a'*64)+'"}')
            with self.assertRaises(AssertionError):v.validar_estado(p)
    def test_solo_detecta_procesos_exactos(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)
            for pid,args in [('1',[b'python3',str(v.SCRIPT).encode(),b'vigilar']),('2',[b'python3',str(v.SCRIPT).encode(),b'observar']),('3',[b'python3',b'/otro/supervisor.py',b'vigilar'])]:
                (p/pid).mkdir();(p/pid/'cmdline').write_bytes(b'\0'.join(args))
            self.assertEqual(sorted(v.procesos(p)),[1,2])
if __name__=='__main__':unittest.main()
