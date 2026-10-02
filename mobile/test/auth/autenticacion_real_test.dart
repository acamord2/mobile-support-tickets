import '../soporte/sesion_simulada.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/conexion.dart';
import 'package:tikets/app/network/estado_api.dart';
import 'package:tikets/app/network/rutas_api.dart';
import 'package:tikets/modules/login/servicio_autenticacion.dart';

/// Comprueba opt-in el canal Flutter → API → PostgreSQL sin publicar credenciales.
/// Recibe usuario/password y URL externamente; las ejecuciones habituales omiten
/// este test y el JWT solo se mantiene en memoria para verificar /me y limpieza.
void main() {
  const habilitado = bool.fromEnvironment('RUN_AUTH_TEST');
  const usuario = String.fromEnvironment('DEMO_USERNAME');
  const password = String.fromEnvironment('DEMO_PASSWORD');
  test('Autenticación real y /me con JWT en memoria', () async {
    if (usuario.isEmpty || password.isEmpty) {
      fail('Proporciona la credencial demo externa desde database/PostgreSQL/v1/DATOS_PRUEBA.sql.');
    }
    final conexion = Conexion(ClienteApi());
    addTearDown(conexion.close);
    final resultado = await ServicioAutenticacion(
      conexion,
    ).iniciarSesion(usuario, password);
    expect(resultado.exito, isTrue, reason: resultado.mensaje);
    final sesion = crearSesionSimulada();
    await sesion.establecer(resultado.sesion!);
    final identidad = await conexion.get(RutasApi.me, token: sesion.token);
    expect(identidad.statusCode, EstadoApi.ok);
    expect(identidad.success, isTrue);
    final datos = identidad.data;
    expect(datos is Map<String, dynamic>, isTrue);
    if (datos is Map<String, dynamic>) {
      expect(datos['username'] == usuario, isTrue);
    }
    await sesion.limpiar();
    expect(sesion.existeSesion, isFalse);
    expect(sesion.token, isNull);
  }, skip: !habilitado);
}
