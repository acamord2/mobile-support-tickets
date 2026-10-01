import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/models/ticket_local.dart';
import 'package:tikets/modules/home/main_home.dart';
import 'package:tikets/modules/home/controlador_inicio.dart';
import '../soporte/sesion_simulada.dart';

/// Verifica presentación de agenda y adaptación a teléfono sin HTTP; repositorios
/// y persistencia se prueban separadamente con SQLite real.
void main() {
  late ControladorInicio controlador;
  setUp(() async {
    final sesion = Get.put(crearSesionSimulada(), permanent: true);
    await sesion.establecer(
      SesionUsuario.fromJson({
        'token': 'simulado',
        'user': {'id': 1, 'username': 'prueba', 'name': 'Técnico de prueba'},
      }),
    );
    Get.put(
      ServicioConectividad(
        consultar: () async => [ConnectivityResult.none],
        cambios: const Stream.empty(),
      ),
      permanent: true,
    );
    controlador = Get.find<ControladorInicio>();
  });
  tearDown(Get.reset);
  testWidgets('Agenda muestra identidad, cero real, vacío y acción rápida', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: VistaInicio()));
    await tester.pumpAndSettle();
    expect(find.text(TextosApp.agenda), findsOneWidget);
    expect(find.text('Técnico de prueba'), findsOneWidget);
    expect(find.text('${TextosApp.pendientes}: 0'), findsOneWidget);
    expect(find.text(TextosApp.sinTickets), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Agenda representa Ticket local y programación', (tester) async {
    controlador.agenda.add(
      TicketLocal.desdeFila({
        'id_local': 1,
        'usuario_id': 1,
        'sucursal_id': 10,
        'titulo': 'Problema local',
        'descripcion': 'Descripción',
        'estado': 'Pending',
        'sync_status': 'pending',
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-01T10:00:00Z',
        'scheduled_at': '2026-10-02T09:30:00Z',
      }),
    );
    await tester.pumpWidget(const GetMaterialApp(home: VistaInicio()));
    await tester.pumpAndSettle();
    expect(find.text('Problema local'), findsOneWidget);
    expect(find.text(TextosApp.sinTickets), findsNothing);
    expect(find.text(TextosApp.pendienteLocal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final ancho in [320.0, 360.0]) {
    testWidgets('Agenda no desborda con ancho $ancho y texto ampliado', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: const VistaInicio(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
