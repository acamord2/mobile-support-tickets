import 'package:flutter_test/flutter_test.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/network/estado_api.dart';
import 'package:tikets/app/network/respuesta_api.dart';
import 'package:tikets/app/network/rutas_api.dart';
import 'package:tikets/services/servicio_autenticacion.dart';
import 'conexion_simulada.dart';

/// Comprueba traducción de transporte a sesiones y mensajes sin servidores reales.
/// Usa credenciales arbitrarias de test para verificar payload, errores y tipos
/// evitando acoplar la suite habitual a la cuenta demo o a PostgreSQL.
void main() {
  test(
    '200 convierte identidad y token mediante la ruta y payload existentes',
    () async {
      final conexion = ConexionSimulada(
        () async => const RespuestaApi(
          statusCode: EstadoApi.ok,
          success: true,
          data: {
            'token': 'token-simulado',
            'user': {
              'id': 3,
              'username': 'usuario-prueba',
              'name': 'Nombre de prueba',
            },
          },
        ),
      );
      final resultado = await ServicioAutenticacion(
        conexion,
      ).iniciarSesion('usuario-prueba', 'clave-prueba');
      expect(resultado.exito, isTrue);
      expect(resultado.sesion?.usuario.name, 'Nombre de prueba');
      expect(resultado.sesion?.usuario.id, 3);
      expect(conexion.ruta, RutasApi.login);
      expect(conexion.payload, {
        'username': 'usuario-prueba',
        'password': 'clave-prueba',
      });
      expect(conexion.tokenRecibido, isNull);
    },
  );
  final errores = {
    EstadoApi.badRequest: TextosApp.datosLoginInvalidos,
    EstadoApi.unauthorized: TextosApp.credencialesIncorrectas,
    EstadoApi.internalServerError: TextosApp.errorServidor,
    EstadoApi.serviceUnavailable: TextosApp.errorServidor,
  };
  for (final error in errores.entries) {
    test('HTTP ${error.key} produce un mensaje público controlado', () async {
      final conexion = ConexionSimulada(
        () async => RespuestaApi(
          statusCode: error.key,
          success: false,
          data: {'title': 'Detalle técnico que no debe mostrarse'},
        ),
      );
      final resultado = await ServicioAutenticacion(
        conexion,
      ).iniciarSesion('usuario-prueba', 'clave-prueba');
      expect(resultado.exito, isFalse);
      expect(resultado.mensaje, error.value);
    });
  }
  test(
    'Sin respuesta HTTP y excepción inesperada producen error de conexión',
    () async {
      for (final responder in <Future<RespuestaApi> Function()>[
        () async => const RespuestaApi(success: false),
        () async => throw StateError('Detalle interno que no debe mostrarse'),
      ]) {
        final resultado = await ServicioAutenticacion(
          ConexionSimulada(responder),
        ).iniciarSesion('usuario-prueba', 'clave-prueba');
        expect(resultado.mensaje, TextosApp.errorConexionLogin);
        expect(resultado.sesion, isNull);
      }
    },
  );
  test(
    '200 con JSON inesperado o identidad inválida nunca establece sesión',
    () async {
      for (final datos in <Object?>[
        null,
        [],
        {'token': '', 'user': {}},
        {
          'token': 'token-simulado',
          'user': {'id': '3', 'username': 'u', 'name': 'n'},
        },
        {
          'token': 'token-simulado',
          'user': {'id': 3, 'username': 'u'},
        },
      ]) {
        final conexion = ConexionSimulada(
          () async => RespuestaApi(
            statusCode: EstadoApi.ok,
            success: true,
            data: datos,
          ),
        );
        final resultado = await ServicioAutenticacion(
          conexion,
        ).iniciarSesion('usuario-prueba', 'clave-prueba');
        expect(resultado.sesion, isNull);
        expect(resultado.mensaje, TextosApp.respuestaLoginInvalida);
      }
    },
  );
}
