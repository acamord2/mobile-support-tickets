import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/esquema_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/database/repositorio_eventos.dart';
import 'package:tikets/app/database/repositorio_solicitudes.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/models/tipo_solicitud_estado.dart';
import 'package:tikets/models/tipo_evento_ticket.dart';
import 'package:tikets/models/sesion_usuario.dart';
import 'package:tikets/modules/home/controlador_inicio.dart';
import 'package:tikets/modules/home/seccion_coordinador.dart';
import '../soporte/sesion_simulada.dart';

/// Verifica decisiones local-first, identidad, motivos y conservación integral de la base anterior.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite cn;
  late OperacionesSqlite sql;
  late RepositorioTickets tickets;
  late RepositorioSolicitudes solicitudes;
  setUp(() {
    cn = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    sql = OperacionesSqlite(cn);
    tickets = RepositorioTickets(sql);
    solicitudes = RepositorioSolicitudes(sql);
  });
  tearDown(() async {
    Get.reset();
    await cn.cerrar();
  });
  Future<int> crear(int usuario, int rol) => tickets.crear(
    usuario: usuario,
    rol: rol,
    sucursal: 10,
    titulo: 'Incidencia',
    descripcion: 'Problema',
    programado: null,
  );

  test(
    'Usuario crea sin programación y solicitud no resuelve; motivo y duplicados se validan',
    () async {
      final id = await crear(6, 4);
      expect((await tickets.obtener(id, 6))!.programado, isNull);
      expect((await tickets.obtener(id, 6))!.tecnicoId, isNull);
      await expectLater(
        solicitudes.crear(
          id,
          6,
          4,
          'Reportante',
          TipoSolicitudEstado.cancelacion,
          '  ',
        ),
        throwsStateError,
      );
      final s = await solicitudes.crear(
        id,
        6,
        4,
        'Reportante',
        TipoSolicitudEstado.resolucion,
        null,
      );
      expect((await tickets.obtener(id, 6))!.estado, 'Pending');
      expect((await solicitudes.obtener(s, 6))!['estado'], 'PENDIENTE');
      await expectLater(
        solicitudes.crear(
          id,
          6,
          4,
          'Reportante',
          TipoSolicitudEstado.resolucion,
          null,
        ),
        throwsStateError,
      );
      await expectLater(
        solicitudes.revisar(s, 6, 4, 'Reportante', true),
        throwsStateError,
      );
      expect(
        (await RepositorioEventos(
          sql,
        ).listar(id, 6)).map((e) => e['tipo_evento']),
        ['CREADO', 'SOLICITUD_RESOLUCION'],
      );
      expect(
        OperacionesSqlite.exigir(
          await RepositorioCola(sql).obtenerPendientes(usuarioId: 6),
        ).where((p) => p.recurso == 'solicitudes'),
        hasLength(1),
      );
    },
  );

  test(
    'Rechazo conserva estado; aprobación finaliza y conserva solicitante/revisor distintos',
    () async {
      final id = await crear(1, 2);
      await tickets.actualizar(
        id,
        1,
        titulo: 'Incidencia',
        descripcion: 'Problema',
        estado: 'InProgress',
        programado: null,
      );
      final original = (await tickets.obtener(id, 1))!;
      await tickets.descargar(
        5,
        [
          {
            ...original.paraCrear(),
            'id': 70,
            'technicianId': 1,
            'reporterUserId': 1,
            'status': 'InProgress',
          },
        ],
        rol: 3,
        tecnicos: {1},
      );
      final local = (await tickets.agenda(5)).single;
      final dato = {
        'id': 100,
        'ticketId': 70,
        'requesterUserId': 1,
        'requesterName': 'Operador',
        'type': 'SOLICITUD_CANCELACION',
        'reason': 'No requiere atención',
        'status': 'PENDIENTE',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'clientRequestId': original.clientRequestId,
      };
      await solicitudes.descargar(5, [dato]);
      final s = (await solicitudes.listar(5)).single;
      await solicitudes.revisar(
        s['id_local'] as int,
        5,
        3,
        'Coordinador',
        false,
      );
      expect((await tickets.obtener(local.idLocal, 5))!.estado, 'InProgress');
      expect(
        (await solicitudes.obtener(s['id_local'] as int, 5))!['estado'],
        'RECHAZADA',
      );
      await expectLater(
        solicitudes.revisar(s['id_local'] as int, 5, 3, 'Coordinador', true),
        throwsStateError,
      );
      await solicitudes.descargar(5, [
        {
          ...dato,
          'id': 101,
          'clientRequestId': '00000000-0000-4000-8000-000000000002',
        },
      ]);
      final pendiente = (await solicitudes.listar(5, pendientes: true)).single;
      await solicitudes.revisar(
        pendiente['id_local'] as int,
        5,
        3,
        'Coordinador',
        true,
      );
      final finalizado = (await tickets.obtener(local.idLocal, 5))!;
      expect(finalizado.estado, 'Cancelled');
      expect(finalizado.clientRequestId, original.clientRequestId);
      final revisada = (await solicitudes.obtener(
        pendiente['id_local'] as int,
        5,
      ))!;
      expect(revisada['requester_user_id'], 1);
      expect(revisada['reviewed_by_user_id'], 5);
      expect(
        (await RepositorioEventos(
          sql,
        ).listar(local.idLocal, 5)).map((e) => e['tipo_evento']),
        ['CANCELACION_RECHAZADA', 'CANCELACION_APROBADA', 'CANCELADO'],
      );
    },
  );

  test('Evidencia inicial se enlaza a CREADO sin Base64 en eventos', () async {
    final id = await tickets.crear(
      usuario: 6,
      rol: 4,
      sucursal: 10,
      titulo: 'Reporte',
      descripcion: 'Problema',
      programado: null,
      evidencia: {
        'descripcion': 'Fotografía inicial',
        'photo_base64': 'imagen-procesada',
        'mime': 'image/jpeg',
      },
    );
    final e = (await RepositorioEventos(sql).listar(id, 6)).single;
    expect(e['tipo_evento'], 'CREADO');
    expect(e['evidencia_id_local'], isNotNull);
    expect(e['photo_base64'], 'imagen-procesada');
    final columnas = await cn.ejecutar(
      (db) => db.rawQuery('PRAGMA table_info(ticket_eventos)'),
    );
    expect(columnas.any((c) => c['name'] == 'photo_base64'), isFalse);
  });

  test(
    'Acordeón empieza cerrado y nunca conserva dos secciones abiertas',
    () async {
      final sesion = crearSesionSimulada();
      await sesion.establecer(
        SesionUsuario.fromJson({
          'token': 'simulado',
          'user': {
            'id': 5,
            'username': 'prueba',
            'name': 'Coordinador',
            'roleId': 3,
            'role': 'Coordinador',
          },
        }),
      );
      final c = ControladorInicio(sesion);
      expect(c.seccionAbierta.value, isNull);
      c.alternarSeccion(SeccionCoordinador.misTickets);
      expect(c.seccionAbierta.value, SeccionCoordinador.misTickets);
      c.alternarSeccion(SeccionCoordinador.tecnicos);
      expect(c.seccionAbierta.value, SeccionCoordinador.tecnicos);
      c.alternarSeccion(SeccionCoordinador.solicitudes);
      expect(c.seccionAbierta.value, SeccionCoordinador.solicitudes);
      c.alternarSeccion(SeccionCoordinador.solicitudes);
      expect(c.seccionAbierta.value, isNull);
      c.onClose();
    },
  );

  test(
    'Migración 5 a 6 conserva todas las filas, referencias y pendientes',
    () async {
      final dir = await Directory.systemTemp.createTemp('workflow-v5-');
      final ruta = '${dir.path}/prueba.db';
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(version: 5, onCreate: EsquemaSqlite.crear),
      );
      await vieja.insert('tickets', {
        'id_local': 9,
        'id_remoto': 70,
        'usuario_id': 1,
        'sucursal_id': 10,
        'titulo': 'Anterior',
        'descripcion': 'Trabajo',
        'estado': 'InProgress',
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-01T10:00:00Z',
        'scheduled_at': '2026-10-02T10:00:00Z',
        'sync_status': 'pending',
        'tecnico_id': 1,
      });
      await vieja.insert('evidencias', {
        'id_local': 8,
        'ticket_id_local': 9,
        'usuario_id': 1,
        'descripcion': 'Foto',
        'photo_base64': 'foto',
        'created_at': '2026-10-01T10:00:00Z',
        'sync_status': 'pending',
      });
      await vieja.insert('ticket_eventos', {
        'id_local': 7,
        'ticket_id_local': 9,
        'usuario_id': 1,
        'autor_id': 1,
        'tipo_evento': 'SEGUIMIENTO',
        'descripcion': 'Anterior',
        'created_at': '2026-10-01T10:00:00Z',
        'client_request_id': 'evento-anterior',
        'evidencia_id_local': 8,
        'sync_status': 'pending',
      });
      final antes = <String, List<Map<String, Object?>>>{};
      for (final tabla in [
        'tickets',
        'evidencias',
        'ticket_eventos',
        'sesion_local',
        'cola_sincronizacion',
      ]) {
        antes[tabla] = await vieja.query(tabla);
      }
      await vieja.close();
      final nueva = ConexionSqlite(fabrica: databaseFactoryFfi, ruta: ruta);
      try {
        for (final tabla in antes.keys) {
          expect(await nueva.ejecutar((db) => db.query(tabla)), antes[tabla]);
        }
        expect(
          await nueva.ejecutar((db) => db.rawQuery('PRAGMA foreign_key_check')),
          isEmpty,
        );
        final repo = RepositorioTickets(OperacionesSqlite(nueva));
        final id = await repo.crear(
          usuario: 6,
          rol: 4,
          sucursal: 10,
          titulo: 'Nuevo',
          descripcion: 'Sin cita',
          programado: null,
        );
        expect(id, greaterThan(9));
        expect((await repo.obtener(id, 6))!.programado, isNull);
        await RepositorioEventos(
          repo.sql,
        ).agregar(id, 6, TipoEventoTicket.solicitudResolucion, 'Solicitud');
      } finally {
        await nueva.cerrar();
        await File(ruta).delete();
        await dir.delete();
      }
    },
  );
}
