import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tikets/main.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/services/servicio_sesion.dart';
import 'package:tikets/views/vista_inicio.dart';
import 'package:tikets/views/vista_login.dart';

/// Ejecuta el formulario real en Android contra API y PostgreSQL de desarrollo.
/// Obtiene credenciales externamente para no incluir la cuenta demo en tests,
/// verifica navegación/logout y captura solo pantallas públicas, nunca el JWT.
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
    expect(find.byType(VistaLogin), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('login');
    await tester.enterText(find.byType(TextField).first, usuario);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.tap(find.text(TextosApp.iniciarSesion));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Rutas.inicio);
    expect(find.byType(VistaInicio), findsOneWidget);
    final sesion = Get.find<ServicioSesion>();
    expect(sesion.existeSesion, isTrue);
    expect(find.text(sesion.usuario!.name), findsOneWidget);
    expect(Get.key.currentState!.canPop(), isFalse);
    await binding.takeScreenshot('inicio');
    await tester.tap(find.text(TextosApp.cerrarSesion));
    await tester.pumpAndSettle();
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
