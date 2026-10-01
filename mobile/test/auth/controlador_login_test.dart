import '../soporte/sesion_simulada.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/network/estado_api.dart';
import 'package:tikets/app/network/i_conexion_api.dart';
import 'package:tikets/app/network/respuesta_api.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/modules/login/controlador_login.dart';
import 'package:tikets/main.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/modules/login/main_login.dart';
import 'package:tikets/modules/home/main_home.dart';
import 'conexion_simulada.dart';

/// Prueba el controlador con navegación real GetX y transporte simulado.
/// Verifica validación, carga, sesión y logout a través de las vistas para detectar
/// errores de binding/ciclo de vida sin credenciales demo ni conexiones externas.
void main() {
  setUp(() => Get.put(crearSesionSimulada(), permanent: true));
  tearDown(Get.reset);
  testWidgets('Login inicia vacío, oculta contraseña y rechaza campos vacíos', (
    tester,
  ) async {
    final conexion = ConexionSimulada(
      () async => const RespuestaApi(success: false),
    );
    Get.put<IConexionApi>(conexion, permanent: true);
    await tester.pumpWidget(const AppTickets());
    await tester.pumpAndSettle();
    final controlador = Get.find<ControladorLogin>();
    expect(Get.currentRoute, Rutas.login);
    expect(find.byType(VistaLogin), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    await controlador.iniciarSesion();
    await tester.pump();
    expect(conexion.peticiones, 0);
    expect(find.text(TextosApp.camposLoginRequeridos), findsOneWidget);
  });
  testWidgets('401 mantiene login y comunica error sin sesión', (tester) async {
    Get.put<IConexionApi>(
      ConexionSimulada(
        () async => const RespuestaApi(
          statusCode: EstadoApi.unauthorized,
          success: false,
        ),
      ),
      permanent: true,
    );
    await tester.pumpWidget(const AppTickets());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'usuario-prueba');
    await tester.enterText(find.byType(TextField).last, 'clave-prueba');
    await tester.tap(find.text(TextosApp.iniciarSesion));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Rutas.login);
    expect(find.text(TextosApp.credencialesIncorrectas), findsOneWidget);
    expect(Get.find<ServicioSesion>().existeSesion, isFalse);
  });
  testWidgets(
    'Carga bloquea duplicados; éxito sustituye login; logout limpia y libera',
    (tester) async {
      final espera = Completer<RespuestaApi>();
      final conexion = ConexionSimulada(() => espera.future);
      Get.put<IConexionApi>(conexion, permanent: true);
      await tester.pumpWidget(const AppTickets());
      await tester.pumpAndSettle();
      final controlador = Get.find<ControladorLogin>();
      await tester.enterText(find.byType(TextField).first, 'usuario-prueba');
      await tester.enterText(find.byType(TextField).last, 'clave-prueba');
      final peticion = controlador.iniciarSesion();
      await tester.pump();
      await controlador.iniciarSesion();
      expect(controlador.cargando.value, isTrue);
      expect(conexion.peticiones, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      espera.complete(
        const RespuestaApi(
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
      await peticion;
      await tester.pumpAndSettle();
      final sesion = Get.find<ServicioSesion>();
      expect(sesion.existeSesion, isTrue);
      expect(Get.currentRoute, Rutas.inicio);
      expect(find.byType(VistaInicio), findsOneWidget);
      expect(find.text('Nombre de prueba'), findsOneWidget);
      expect(Get.key.currentState!.canPop(), isFalse);
      expect(controlador.isClosed, isTrue);
      await tester.tap(find.text(TextosApp.cerrarSesion));
      await tester.pumpAndSettle();
      expect(sesion.usuario, isNull);
      expect(sesion.token, isNull);
      expect(Get.currentRoute, Rutas.login);
      expect(Get.key.currentState!.canPop(), isFalse);
      expect(Get.find<ControladorLogin>().contrasena.text, isEmpty);
    },
  );
}
