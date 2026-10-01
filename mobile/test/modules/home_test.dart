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
import 'package:tikets/modules/home/filtro_agenda.dart';
import 'package:tikets/modules/home/widgets_home/cabecera_inicio.dart';
import 'package:tikets/app/theme/colores_app.dart';
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
  test('Filtros múltiples alternan OR sin cambiar conteos ni orden', () {
    for (final filtro in FiltroAgenda.values) {
      controlador.agenda.add(
        TicketLocal.desdeFila({
          'id_local': filtro.index + 1,
          'usuario_id': 1,
          'sucursal_id': 10,
          'titulo': filtro.texto,
          'descripcion': 'Prueba',
          'estado': filtro.estado,
          'sync_status': 'synced',
          'created_at': '2026-10-01T10:00:00Z',
          'updated_at': '2026-10-01T10:00:00Z',
          'scheduled_at': '2026-10-02T09:30:00Z',
        }),
      );
    }
    controlador.conteos.assignAll({
      'Pending': 1,
      'InProgress': 1,
      'Resolved': 1,
    });
    final conteos = Map.of(controlador.conteos);
    List<int> visibles() =>
        controlador.ticketsVisibles.map((t) => t.idLocal).toList();
    expect(controlador.filtrosSeleccionados, isEmpty);
    expect(visibles(), [1, 2, 3]);
    controlador.alternarFiltro(FiltroAgenda.pendiente);
    expect(visibles(), [1]);
    controlador.alternarFiltro(FiltroAgenda.pendiente);
    expect(visibles(), [1, 2, 3]);
    controlador.alternarFiltro(FiltroAgenda.enAtencion);
    expect(visibles(), [2]);
    controlador.alternarFiltro(FiltroAgenda.pendiente);
    expect(visibles(), [1, 2]);
    controlador.alternarFiltro(FiltroAgenda.resuelto);
    expect(visibles(), [1, 2, 3]);
    controlador.alternarFiltro(FiltroAgenda.enAtencion);
    expect(controlador.filtrosSeleccionados, {
      FiltroAgenda.pendiente,
      FiltroAgenda.resuelto,
    });
    expect(visibles(), [1, 3]);
    expect(controlador.conteos, conteos);
  });
  testWidgets(
    'Filtro seleccionado tiene borde y vacío específico; desmarcar restaura vacío general',
    (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: VistaInicio()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TextosApp.pendientes));
      await tester.pump();
      expect(find.text(TextosApp.sinTicketsFiltrados), findsOneWidget);
      final boton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text(TextosApp.pendientes),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(boton.style!.side!.resolve({})!.width, 2);
      expect(boton.style!.side!.resolve({})!.color, ColoresApp.seleccion);
      await tester.tap(find.text(TextosApp.pendientes));
      await tester.pump();
      expect(find.text(TextosApp.sinTickets), findsOneWidget);
      expect(controlador.filtrosSeleccionados, isEmpty);
    },
  );
  testWidgets(
    'Header delega sincronización y menú; carga deshabilita el envío',
    (tester) async {
      var envios = 0, salidas = 0;
      Widget cabecera(bool cargando) => GetMaterialApp(
        home: Scaffold(
          body: CabeceraInicio(
            nombreTecnico: controlador.nombreTecnico,
            saludo: controlador.saludo,
            sincronizando: cargando,
            alSincronizar: () => envios++,
            alCerrarSesion: () => salidas++,
          ),
        ),
      );
      await tester.pumpWidget(cabecera(false));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.sync));
      expect(envios, 1);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TextosApp.cerrarSesion));
      await tester.pumpAndSettle();
      expect(salidas, 1);
      await tester.pumpWidget(cabecera(true));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton).first).onPressed,
        isNull,
      );
      expect(envios, 1);
    },
  );
  testWidgets('Agenda muestra identidad, cero real, vacío y acción rápida', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: VistaInicio()));
    await tester.pumpAndSettle();
    expect(find.text(TextosApp.soporteTecnico), findsOneWidget);
    expect(find.text(TextosApp.agenda), findsNothing);
    expect(find.text(controlador.saludo), findsOneWidget);
    expect(find.text('Técnico de prueba'), findsOneWidget);
    expect(find.text(TextosApp.pendientes), findsOneWidget);
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
