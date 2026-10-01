import 'soporte/sesion_simulada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tikets/main.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/modules/login/main_login.dart';
import 'package:tikets/app/constants/textos_app.dart';

/// Comprueba que el arranque resuelva login sin credenciales precargadas.
/// Monta GetX y verifica la presentación inicial; limpia DI al terminar para
/// mantener la prueba independiente de una sesión o conexión anterior.
void main() {
  setUp(() => Get.put(crearSesionSimulada(), permanent: true));
  tearDown(Get.reset);
  testWidgets('Muestra Login como ruta inicial', (tester) async {
    await tester.pumpWidget(const AppTickets());
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Rutas.login);
    expect(find.byType(VistaLogin), findsOneWidget);
    expect(find.text(TextosApp.appName), findsOneWidget);
    for (final campo in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(campo.controller!.text, isEmpty);
    }
  });
}
