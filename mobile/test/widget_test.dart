import 'package:flutter_test/flutter_test.dart';
import 'package:tikets/main.dart';
import 'package:tikets/app/routes/app_routes.dart';
import 'package:tikets/views/initial_view.dart';
import 'package:get/get.dart';
import 'package:tikets/app/constants/app_texts.dart';

/// Verifica que GetX resuelva la ruta inicial y muestre la vista de plantilla.
/// Monta la aplicación y espera la navegación para detectar registros de rutas
/// incorrectos antes de agregar funcionalidades. Limpia GetX entre pruebas.
void main() {
  tearDown(Get.reset);
  testWidgets('Muestra la pantalla inicial', (tester) async {
    await tester.pumpWidget(const TicketsApp());
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.initial);
    expect(find.byType(InitialView), findsOneWidget);
    expect(find.text(AppTexts.appName), findsOneWidget);
  });
}
