import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/network/i_conexion_api.dart';
import 'package:tikets/app/network/respuesta_api.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/main.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/modules/home/main_home.dart';
import '../auth/conexion_simulada.dart';
import '../soporte/sesion_simulada.dart';

/// Prueba arranque local-first sin HTTP ni plugins de almacenamiento del equipo.
/// Demuestra Home restaurado offline y rechazo de primer login sin red.
void main() {
  tearDown(Get.reset);
  testWidgets(
    'Arranque restaura Home offline sin mostrar Login ni solicitar API',
    (tester) async {
      final repo = RepositorioSesionSimulado();
      await ServicioSesion(repo).establecer(
        SesionUsuario.fromJson({
          'token': 'token-ficticio',
          'user': {'id': 7, 'username': 'prueba', 'name': 'Técnico de prueba'},
        }),
      );
      Get.put(ServicioSesion(repo), permanent: true);
      final red = ServicioConectividad(
        consultar: () async => [ConnectivityResult.none],
        cambios: const Stream.empty(),
      );
      Get.put(red, permanent: true);
      final api = ConexionSimulada(
        () async => const RespuestaApi(success: false),
      );
      Get.put<IConexionApi>(api, permanent: true);
      await tester.pumpWidget(const AppTickets());
      expect(find.byType(TextField), findsNothing);
      await tester.pumpAndSettle();
      expect(Get.currentRoute, Rutas.inicio);
      expect(find.byType(VistaInicio), findsOneWidget);
      expect(find.text('Técnico de prueba'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(api.peticiones, 0);
    },
  );
  testWidgets('Instalación sin identidad permanece en Login y necesita red', (
    tester,
  ) async {
    Get.put(crearSesionSimulada(), permanent: true);
    Get.put(
      ServicioConectividad(
        consultar: () async => [ConnectivityResult.none],
        cambios: const Stream.empty(),
      ),
      permanent: true,
    );
    final api = ConexionSimulada(
      () async => const RespuestaApi(success: false),
    );
    Get.put<IConexionApi>(api, permanent: true);
    await tester.pumpWidget(const AppTickets());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'prueba');
    await tester.enterText(find.byType(TextField).last, 'clave-ficticia');
    await tester.tap(find.text(TextosApp.iniciarSesion));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Rutas.login);
    expect(find.text(TextosApp.loginRequiereConexion), findsOneWidget);
    expect(Get.find<ServicioSesion>().existeSesion, isFalse);
    expect(api.peticiones, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      isEmpty,
    );
  });
}
