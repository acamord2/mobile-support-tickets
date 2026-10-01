import 'package:flutter_test/flutter_test.dart';
import 'package:tikets/main.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/views/vista_inicial.dart';
import 'package:get/get.dart';
import 'package:tikets/app/constants/textos_app.dart';

/// Verifica que GetX resuelva la ruta inicial y muestre la vista de plantilla.
/// Monta la aplicación y espera la navegación para detectar registros de rutas
/// incorrectos antes de agregar funcionalidades. Limpia GetX entre pruebas.
void main() {
  tearDown(Get.reset);
  testWidgets('Muestra la pantalla inicial', (tester) async {
    await tester.pumpWidget(const AppTickets());
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Rutas.initial);
    expect(find.byType(VistaInicial), findsOneWidget);
    expect(find.text(TextosApp.appName), findsOneWidget);
  });
}
