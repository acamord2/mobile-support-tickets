import '../soporte/sesion_simulada.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/main.dart';
import 'package:tikets/app/network/i_conexion_api.dart';
import 'package:tikets/app/network/conexion.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/modules/login/main_login.dart';
import 'package:tikets/modules/home/main_home.dart';
import 'package:tikets/modules/login/widgets_login/formulario_login.dart';
import 'package:tikets/modules/home/widgets_home/resumen_agenda.dart';
import 'package:tikets/widgets/apartada/indicador_desconexion.dart';

/// Verifica composición modular e indicador transversal con conectividad simulada.
/// Usa identidad ficticia en memoria y navegación GetX sin HTTP ni PostgreSQL.
void main() {
  setUp(() => Get.put(crearSesionSimulada(), permanent: true));
  tearDown(Get.reset);
  testWidgets(
    'Login/Home reutilizan indicador que aparece solo al perder red',
    (tester) async {
      final red = Get.put(
        ServicioConectividad(
          consultar: () async => [ConnectivityResult.wifi],
          cambios: const Stream.empty(),
        ),
        permanent: true,
      );
      await tester.pumpWidget(const AppTickets());
      await tester.pumpAndSettle();
      expect(find.byType(VistaLogin), findsOneWidget);
      final canal = Get.find<IConexionApi>() as Conexion;
      expect(find.byType(FormularioLogin), findsOneWidget);
      expect(find.byType(IndicadorDesconexion), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      red.redDisponible.value = false;
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(
        tester.getTopRight(find.byIcon(Icons.cloud_off)).dx,
        greaterThan(700),
      );
      final sesion = Get.find<ServicioSesion>();
      await sesion.establecer(
        SesionUsuario.fromJson({
          'token': 'token-simulado',
          'user': {'id': 2, 'username': 'prueba', 'name': 'Persona de prueba'},
        }),
      );
      Get.offAllNamed<void>(Rutas.inicio);
      await tester.pumpAndSettle();
      expect(find.byType(VistaInicio), findsOneWidget);
      expect(Get.find<IConexionApi>(), same(canal));
      expect(canal.isClosed, isFalse);
      expect(find.byType(ResumenAgenda), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Persona de prueba'), findsOneWidget);
      red.redDisponible.value = true;
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      await tester.tap(find.text(TextosApp.cerrarSesion));
      await tester.pumpAndSettle();
      expect(find.byType(VistaLogin), findsOneWidget);
      expect(sesion.existeSesion, isFalse);
      expect(Get.find<IConexionApi>(), same(canal));
      expect(canal.isClosed, isFalse);
    },
  );
}
