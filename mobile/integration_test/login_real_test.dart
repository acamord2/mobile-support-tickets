import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tikets/main.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/modules/home/main_home.dart';
import 'package:tikets/modules/login/main_login.dart';

/// Espera navegación mientras concluye IO nativo de SQLite o almacén seguro.
/// Evita asumir que ausencia de animaciones significa que terminó persistencia.
Future<void> esperarRuta(WidgetTester tester, String ruta) async {
  for (var intento = 0; intento < 200; intento++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (Get.currentRoute == ruta) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('No concluyó la navegación esperada.');
}

/// Ejecuta el formulario real en Android contra API y PostgreSQL de desarrollo.
/// Obtiene credenciales externamente para no incluir la cuenta demo en tests,
/// verifica navegación/logout y captura solo pantallas públicas, nunca el JWT.
/// Simula el indicador offline mediante su estado sin cambiar la red del teléfono.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const usuario = String.fromEnvironment('DEMO_USERNAME');
  const password = String.fromEnvironment('DEMO_PASSWORD');
  testWidgets('Login real, identidad pública y cierre de sesión en Android', (
    tester,
  ) async {
    if (usuario.isEmpty || password.isEmpty) {
      fail('Proporciona la credencial externa documentada en DATOS_PRUEBA.md.');
    }
    await tester.pumpWidget(const AppTickets());
    await tester.pumpAndSettle();
    if (Get.currentRoute == Rutas.inicio) {
      expect(await Get.find<ServicioSesion>().limpiar(), isTrue);
      Get.offAllNamed<void>(Rutas.login);
    }
    await esperarRuta(tester, Rutas.login);
    expect(find.byType(VistaLogin), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('login');
    await tester.enterText(find.byType(TextField).first, usuario);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.tap(find.text(TextosApp.iniciarSesion));
    await esperarRuta(tester, Rutas.inicio);
    expect(Get.currentRoute, Rutas.inicio);
    expect(find.byType(VistaInicio), findsOneWidget);
    final sesion = Get.find<ServicioSesion>();
    expect(sesion.existeSesion, isTrue);
    expect(find.text(sesion.usuario!.name), findsOneWidget);
    expect(Get.key.currentState!.canPop(), isFalse);
    expect(find.text(TextosApp.misTickets), findsOneWidget);
    expect(find.text(TextosApp.sincronizar), findsOneWidget);
    expect(find.text(TextosApp.moduloNoDisponible), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('inicio');
    final conectividad = Get.find<ServicioConectividad>();
    conectividad.redDisponible.value = false;
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(Get.currentRoute, Rutas.inicio);
    await binding.takeScreenshot('inicio_sin_red');
    await conectividad.refrescar();
    await tester.pump();
    await tester.tap(find.text(TextosApp.cerrarSesion));
    await esperarRuta(tester, Rutas.login);
    expect(Get.currentRoute, Rutas.login);
    expect(sesion.usuario, isNull);
    expect(sesion.token, isNull);
    expect(Get.key.currentState!.canPop(), isFalse);
    for (final campo in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(campo.controller!.text, isEmpty);
    }
    await binding.takeScreenshot('sesion_cerrada');
  });
}
