import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/database/repositorio_sucursales.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/database/operacion_pendiente.dart';
import 'package:tikets/app/database/estado_sincronizacion.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tikets/app/routes/paginas_app.dart';
import 'package:tikets/app/routes/rutas.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/modules/detalle_ticket/controlador_detalle_ticket.dart';
import 'package:tikets/modules/detalle_ticket/main_detalle_ticket.dart';
import 'package:tikets/modules/detalle_ticket/widgets_detalle_ticket/accion_detalle_ticket.dart';
import 'package:tikets/modules/home/controlador_inicio.dart';
import 'package:tikets/modules/home/main_home.dart';
import 'package:tikets/modules/home/filtro_agenda.dart';
import '../soporte/sesion_simulada.dart';

/// Evita IO automático en el reloj virtual de widgets; las cargas explícitas
/// y el regreso de abrirDetalle utilizan métodos reales y SQLite real.
class InicioPruebaDetalle extends ControladorInicio {
  InicioPruebaDetalle(super.sesion, {super.repositorio, super.sucursales});
  @override
  void onReady() {}
}

/// Comprueba atención offline y navegación con SQLite real, sin canal HTTP registrado.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite cn;
  late OperacionesSqlite sql;
  late RepositorioTickets tickets;
  late RepositorioSucursales sucursales;
  late ServicioSesion sesion;
  late ControladorDetalleTicket detalle;
  setUp(() async {
    cn = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    sql = OperacionesSqlite(cn);
    tickets = Get.put(RepositorioTickets(sql));
    sucursales = Get.put(RepositorioSucursales(sql));
    Get.put(RepositorioEvidencias(sql));
    Get.lazyPut<ControladorInicio>(
      () => InicioPruebaDetalle(
        Get.find<ServicioSesion>(),
        repositorio: tickets,
        sucursales: sucursales,
      ),
      fenix: true,
    );
    sesion = Get.put(crearSesionSimulada(), permanent: true);
    await sesion.establecer(
      SesionUsuario.fromJson({
        'token': 'simulado',
        'user': {'id': 1, 'username': 'prueba', 'name': 'Persona de prueba'},
      }),
    );
    Get.put(
      ServicioConectividad(
        consultar: () async => [ConnectivityResult.none],
        cambios: const Stream.empty(),
      ),
      permanent: true,
    );
    await sucursales.guardar(1, [
      {'id': 10, 'name': 'Sucursal local', 'address': 'Dirección local'},
    ]);
    await tickets.descargar(
      1,
      List.generate(
        3,
        (i) => {
          'id': 11 + i,
          'branchId': 10,
          'technicianId': 1,
          'title': 'Problema ${i + 1}',
          'description': 'Descripción local ${i + 1}',
          'status': ['Pending', 'InProgress', 'Resolved'][i],
          'clientRequestId': null,
          'createdAt': '2026-10-01T10:00:00Z',
          'updatedAt': '2026-10-01T10:00:00Z',
          'scheduledAt': '2026-10-02T09:30:00Z',
        },
      ),
    );
    detalle = ControladorDetalleTicket(
      tickets,
      sucursales,
      sesion,
      Get.find<RepositorioEvidencias>(),
    );
  });
  tearDown(() async {
    Get.reset();
    await cn.cerrar();
  });

  test(
    'Carga ticket y sucursal exclusivamente locales del propietario',
    () async {
      await detalle.cargar(1);
      expect(detalle.ticket.value!.idRemoto, 11);
      expect(detalle.ticket.value!.titulo, 'Problema 1');
      expect(detalle.sucursal.value!.direccion, 'Dirección local');
      expect(detalle.puedeComenzar, isTrue);
      expect(detalle.error.value, isEmpty);
    },
  );
  test(
    'Offline actualiza SQLite y encola una sola actualización ante doble pulsación',
    () async {
      await detalle.cargar(1);
      final previo = detalle.ticket.value!;
      await Future.wait([
        detalle.comenzarAtencion(),
        detalle.comenzarAtencion(),
      ]);
      final actual = (await tickets.obtener(1, 1))!;
      expect(actual.estado, 'InProgress');
      expect(detalle.estadoTexto, TextosApp.enAtencion);
      expect(detalle.puedeComenzar, isFalse);
      expect(actual.syncStatus, 'pending');
      expect(actual.idLocal, previo.idLocal);
      expect(actual.idRemoto, previo.idRemoto);
      expect(actual.clientRequestId, previo.clientRequestId);
      expect(actual.creado, previo.creado);
      expect(actual.programado, previo.programado);
      final cola = OperacionesSqlite.exigir(
        await RepositorioCola(sql).obtenerPendientes(usuarioId: 1),
      );
      expect(cola.where((p) => p.recurso == 'eventos'), hasLength(1));
      final colaTickets = cola.where((p) => p.recurso == 'tickets').toList();
      expect(colaTickets, hasLength(1));
      expect(colaTickets.single.usuarioId, 1);
      expect(colaTickets.single.recurso, 'tickets');
      expect(colaTickets.single.operacion, TipoOperacionLocal.actualizar);
      expect(colaTickets.single.payload['id_local'], 1);
      expect(colaTickets.single.payload['status'], 'InProgress');
      expect(
        colaTickets.single.payload['scheduledAt'],
        previo.programado.toUtc().toIso8601String(),
      );
      expect(colaTickets.single.estado, EstadoSincronizacion.pendiente);
      expect(colaTickets.single.intentos, 0);
      expect(colaTickets.single.ultimoError, isNull);
    },
  );
  for (final id in [2, 3]) {
    test('Ticket $id no permite comenzar ni volver a Pendiente', () async {
      await detalle.cargar(id);
      final estado = detalle.ticket.value!.estado;
      await detalle.comenzarAtencion();
      expect(detalle.puedeComenzar, isFalse);
      expect((await tickets.obtener(id, 1))!.estado, estado);
      expect(
        OperacionesSqlite.exigir(
          await RepositorioCola(sql).obtenerPendientes(usuarioId: 1),
        ),
        isEmpty,
      );
    });
  }
  test('Ausente o ajeno no carga información ni genera operaciones', () async {
    await detalle.cargar(99);
    expect(detalle.ticket.value, isNull);
    expect(detalle.error.value, TextosApp.ticketNoDisponible);
    await tickets.descargar(2, [
      {
        'id': 20,
        'branchId': 10,
        'technicianId': 2,
        'title': 'Ajeno',
        'description': 'Otra cuenta',
        'status': 'Pending',
        'clientRequestId': null,
        'createdAt': '2026-10-01T10:00:00Z',
        'updatedAt': '2026-10-01T10:00:00Z',
        'scheduledAt': '2026-10-02T09:30:00Z',
      },
    ]);
    await detalle.cargar(4);
    expect(detalle.ticket.value, isNull);
    expect(detalle.puedeComenzar, isFalse);
  });
  testWidgets(
    'Home abre detalle por Id local, comienza atención y al volver actualiza filtros/conteos',
    (tester) async {
      final home = Get.find<ControladorInicio>();
      await tester.runAsync(() => home.cargar());
      home.alternarFiltro(FiltroAgenda.pendiente);
      await tester.pumpWidget(
        GetMaterialApp(home: const VistaInicio(), getPages: PaginasApp.pages),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Problema 1')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(Get.currentRoute, Rutas.detalleTicket);
      expect(Get.arguments, 1);
      final controller = Get.find<ControladorDetalleTicket>();
      await tester.runAsync(() => controller.cargar(1));
      await tester.pumpAndSettle();
      expect(find.byType(VistaDetalleTicket), findsOneWidget);
      expect(find.text('Descripción local 1'), findsOneWidget);
      expect(find.text('Sucursal local'), findsOneWidget);
      expect(find.text(TextosApp.comenzarAtencion), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text(TextosApp.comenzarAtencion));
        while (controller.guardando.value) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text(TextosApp.comenzarAtencion), findsNothing);
      expect(controller.ticket.value!.estado, 'InProgress');
      await tester.runAsync(() => tester.tap(find.byType(BackButton)));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final limite = DateTime.now().add(const Duration(seconds: 2));
        while (home.conteos['Pending'] != 0 &&
            DateTime.now().isBefore(limite)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(VistaInicio), findsOneWidget);
      expect(sesion.existeSesion, isTrue);
      expect(home.conteos, {'Pending': 0, 'InProgress': 2, 'Resolved': 1});
      expect(home.filtrosSeleccionados, {FiltroAgenda.pendiente});
      expect(home.ticketsVisibles, isEmpty);
      expect(find.text(TextosApp.sinTicketsFiltrados), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final estado in [TextosApp.enAtencion, TextosApp.ticketResuelto]) {
    testWidgets('$estado se presenta sin acciones de edición', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccionDetalleTicket(
              puedeComenzar: false,
              guardando: false,
              estado: estado,
              alComenzar: () => fail('No debe existir acción disponible.'),
            ),
          ),
        ),
      );
      expect(find.text(estado), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(TextosApp.comenzarAtencion), findsNothing);
    });
  }
}
