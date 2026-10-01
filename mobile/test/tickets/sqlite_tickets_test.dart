import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/esquema_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/database/repositorio_sucursales.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';

/// Comprueba SQLite real: preservación, autoría, clave persistente y protección de cambios.
void main() {
  sqfliteFfiInit();
  late ConexionSqlite cn;
  late OperacionesSqlite sql;
  late RepositorioTickets tickets;
  late RepositorioCola cola;
  late RepositorioSucursales ramas;
  setUp(() {
    cn = ConexionSqlite(
      fabrica: databaseFactoryFfi,
      ruta: inMemoryDatabasePath,
    );
    sql = OperacionesSqlite(cn);
    tickets = RepositorioTickets(sql);
    cola = RepositorioCola(sql);
    ramas = RepositorioSucursales(sql);
  });
  tearDown(() => cn.cerrar());
  Future<int> crear({int usuario = 1, DateTime? fecha}) => tickets.crear(
    usuario: usuario,
    sucursal: 10,
    titulo: 'Prueba',
    descripcion: 'Trabajo local',
    programado: fecha ?? DateTime.utc(2026, 10, 1, 9),
  );
  test('Catálogo local aislado por cuenta y actualizable', () async {
    await ramas.guardar(1, [
      {'id': 10, 'name': 'Centro', 'address': 'Dirección'},
    ]);
    await ramas.guardar(2, [
      {'id': 10, 'name': 'Centro B', 'address': 'Otra'},
    ]);
    expect((await ramas.obtener(1)).single.nombre, 'Centro');
    expect((await ramas.obtener(2)).single.nombre, 'Centro B');
  });
  test(
    'Ticket offline conserva tres identidades y una clave UUID persistente',
    () async {
      final id = await crear();
      final t = (await tickets.obtener(id, 1))!;
      expect(t.idLocal, id);
      expect(t.idRemoto, isNull);
      expect(t.syncStatus, 'pending');
      expect(
        t.clientRequestId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      final p = OperacionesSqlite.exigir(
        await cola.obtenerPendientes(usuarioId: 1),
      ).where((p) => p.recurso == 'tickets').single;
      expect(p.usuarioId, 1);
      expect(p.payload, {'id_local': id});
      expect(await tickets.obtener(id, 2), isNull);
      expect(
        OperacionesSqlite.exigir(await cola.obtenerPendientes(usuarioId: 2)),
        isEmpty,
      );
      await cola.marcarProcesando(p.id);
      await tickets.confirmar(id, 105, 1, p.id);
      final finalizado = (await tickets.obtener(id, 1))!;
      expect(finalizado.idLocal, id);
      expect(finalizado.idRemoto, 105);
      expect(finalizado.clientRequestId, t.clientRequestId);
    },
  );
  test(
    'Agenda ordena ScheduledAt independientemente de creación y cuenta estados',
    () async {
      final tarde = await crear(fecha: DateTime.utc(2026, 10, 1, 17));
      final temprano = await crear(fecha: DateTime.utc(2026, 10, 1, 8));
      expect((await tickets.agenda(1)).map((t) => t.idLocal), [
        temprano,
        tarde,
      ]);
      expect((await tickets.conteos(1))['Pending'], 2);
      expect(
        (await tickets.obtener(temprano, 1))!.programado,
        DateTime.utc(2026, 10, 1, 8),
      );
    },
  );
  test(
    'Descarga no pisa pendiente ni UUID; repetida no duplica remoto',
    () async {
      final id = await crear();
      final original = (await tickets.obtener(id, 1))!;
      final remoto = {
        'id': 107,
        'branchId': 10,
        'technicianId': 1,
        'title': 'Servidor',
        'description': 'Remoto',
        'status': 'Resolved',
        'clientRequestId': original.clientRequestId,
        'createdAt': '2026-10-01T10:00:00Z',
        'updatedAt': '2026-10-01T10:00:00Z',
        'scheduledAt': '2026-10-01T11:00:00Z',
      };
      await tickets.descargar(1, [remoto]);
      expect((await tickets.obtener(id, 1))!.titulo, 'Prueba');
      final p = OperacionesSqlite.exigir(
        await cola.obtenerPendientes(usuarioId: 1),
      ).where((p) => p.recurso == 'tickets').single;
      await cola.marcarProcesando(p.id);
      await tickets.confirmar(id, 107, 1, p.id);
      await tickets.descargar(1, [remoto]);
      await tickets.descargar(1, [remoto]);
      expect(await tickets.agenda(1), hasLength(1));
      expect((await tickets.obtener(id, 1))!.titulo, 'Servidor');
      expect(
        (await tickets.obtener(id, 1))!.clientRequestId,
        original.clientRequestId,
      );
    },
  );
  test(
    'Edición durante envío conserva pending y programación sin modificar clave',
    () async {
      final id = await crear();
      final original = (await tickets.obtener(id, 1))!;
      final primera = OperacionesSqlite.exigir(
        await cola.obtenerPendientes(usuarioId: 1),
      ).where((p) => p.recurso == 'tickets').single;
      await cola.marcarProcesando(primera.id);
      await tickets.actualizar(
        id,
        1,
        titulo: 'Editado',
        descripcion: 'Trabajo nuevo',
        estado: 'InProgress',
        programado: DateTime.utc(2026, 10, 3, 12),
      );
      await tickets.confirmar(id, 110, 1, primera.id);
      final actual = (await tickets.obtener(id, 1))!;
      expect(actual.syncStatus, 'pending');
      expect(actual.creado, original.creado);
      expect(actual.clientRequestId, original.clientRequestId);
      expect(actual.programado, DateTime.utc(2026, 10, 3, 12));
      expect((await tickets.conteos(1))['InProgress'], 1);
    },
  );
  test('Evidencia existe con Ticket sin Id remoto y cola propia', () async {
    final id = await crear();
    final evidencias = RepositorioEvidencias(sql);
    final evidencia = await evidencias.crear(
      id,
      1,
      'Diagnóstico',
      base64: base64Encode([1, 2, 3]),
      mime: 'image/jpeg',
    );
    expect((await evidencias.obtener(evidencia, 1))!['ticket_id_local'], id);
    expect(await evidencias.obtener(evidencia, 2), isNull);
    expect(
      OperacionesSqlite.exigir(await cola.obtenerPendientes(usuarioId: 1)),
      hasLength(4),
    );
  });
  test(
    'Migración v2 conserva sesión, cola y token externo; archivo conserva ticket',
    () async {
      final dir = await Directory.systemTemp.createTemp('agenda_migracion_');
      final ruta = '${dir.path}/prueba.db';
      final anterior = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(version: 2, onCreate: EsquemaSqlite.crear),
      );
      await anterior.insert('sesion_local', {
        'id': 1,
        'id_usuario': 7,
        'username': 'prueba',
        'nombre': 'Prueba',
        'autenticado_en': '2026-10-01T10:00:00Z',
      });
      await anterior.insert('cola_sincronizacion', {
        'recurso': 'anterior',
        'operacion': 'crear',
        'payload': '{}',
        'creado_en': '2026-10-01T10:00:00Z',
        'estado': 'pendiente',
      });
      await anterior.close();
      final nueva = ConexionSqlite(fabrica: databaseFactoryFfi, ruta: ruta);
      try {
        final ops = OperacionesSqlite(nueva);
        expect(
          OperacionesSqlite.exigir(
            await ops.seleccionar('sesion_local'),
          ).single['id_usuario'],
          7,
        );
        expect(
          OperacionesSqlite.exigir(
            await ops.seleccionar('cola_sincronizacion'),
          ).single['usuario_id'],
          7,
        );
        final repo = RepositorioTickets(ops);
        final id = await repo.crear(
          usuario: 7,
          sucursal: 1,
          titulo: 'Persiste',
          descripcion: 'Offline',
          programado: DateTime.utc(2026, 10, 1),
        );
        final clave = (await repo.obtener(id, 7))!.clientRequestId;
        await nueva.cerrar();
        expect((await repo.obtener(id, 7))!.clientRequestId, clave);
        expect(
          (await nueva.ejecutar(
            (db) => db.rawQuery('PRAGMA user_version'),
          )).single['user_version'],
          5,
        );
      } finally {
        await nueva.cerrar();
        await Directory(dir.path).delete(recursive: true);
      }
    },
  );
}
