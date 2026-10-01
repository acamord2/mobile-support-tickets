import '../../models/ticket_local.dart';
import 'operaciones_sqlite.dart';
import 'repositorio_cola.dart';
import 'operacion_pendiente.dart';
import 'identificador_cliente.dart';

/// Persiste tickets y operaciones atómicamente usando la conexión SQLite común.
/// La agenda siempre procede de aquí; descargas respetan cambios locales pendientes.
class RepositorioTickets {
  final OperacionesSqlite sql;
  RepositorioTickets(this.sql);

  /// Ordena por programación UTC, creación e Id; restringe datos al técnico actual.
  Future<List<TicketLocal>> agenda(int usuario) async =>
      OperacionesSqlite.exigir(
        await sql.seleccionar(
          'tickets',
          donde: 'usuario_id = ?',
          argumentos: [usuario],
          orden: 'scheduled_at, created_at, id_local',
        ),
      ).map(TicketLocal.desdeFila).toList();

  /// Localiza por Id local y propietario, sin permitir otra cuenta leer un ticket.
  Future<TicketLocal?> obtener(int id, int usuario) async {
    final filas = OperacionesSqlite.exigir(
      await sql.seleccionar(
        'tickets',
        donde: 'id_local = ? AND usuario_id = ?',
        argumentos: [id, usuario],
      ),
    );
    return filas.isEmpty ? null : TicketLocal.desdeFila(filas.single);
  }

  /// Calcula el resumen desde registros locales sin inventar datos cuando no hay descarga.
  Future<Map<String, int>> conteos(int usuario) async {
    final total = {'Pending': 0, 'InProgress': 0, 'Resolved': 0};
    for (final t in await agenda(usuario)) {
      total[t.estado] = total[t.estado]! + 1;
    }
    return total;
  }

  /// Genera la clave una sola vez y guarda ticket y cola dentro de la misma transacción.
  Future<int> crear({
    required int usuario,
    required int sucursal,
    required String titulo,
    required String descripcion,
    required DateTime programado,
    Map<String, Object?>? evidencia,
  }) async {
    return OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final fecha = DateTime.now().toUtc().toIso8601String();
        final id = OperacionesSqlite.exigir(
          await tx.insertar('tickets', {
            'usuario_id': usuario,
            'sucursal_id': sucursal,
            'titulo': titulo.trim(),
            'descripcion': descripcion.trim(),
            'estado': 'Pending',
            'created_at': fecha,
            'updated_at': fecha,
            'scheduled_at': programado.toUtc().toIso8601String(),
            'client_request_id': IdentificadorCliente.crear(),
            'sync_status': 'pending',
          }),
        );
        OperacionesSqlite.exigir(
          await RepositorioCola(tx).agregarPendiente(
            usuarioId: usuario,
            recurso: 'tickets',
            operacion: TipoOperacionLocal.crear,
            payload: {'id_local': id},
          ),
        );
        if (evidencia != null) {
          final foto = OperacionesSqlite.exigir(
            await tx.insertar('evidencias', {
              ...evidencia,
              'ticket_id_local': id,
              'usuario_id': usuario,
              'created_at': fecha,
              'sync_status': 'pending',
            }),
          );
          OperacionesSqlite.exigir(
            await RepositorioCola(tx).agregarPendiente(
              usuarioId: usuario,
              recurso: 'evidencias',
              operacion: TipoOperacionLocal.crear,
              payload: {'id_local': foto},
            ),
          );
        }
        return id;
      }),
    );
  }

  /// Actualiza negocio y cola sin tocar clave, Id local ni fecha de creación.
  /// Siempre encola el cambio para conservar ediciones hechas durante otro envío.
  Future<void> actualizar(
    int id,
    int usuario, {
    required String titulo,
    required String descripcion,
    required String estado,
    required DateTime programado,
  }) async {
    if (!['Pending', 'InProgress', 'Resolved'].contains(estado)) {
      throw const FormatException('Estado inválido.');
    }
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final n = OperacionesSqlite.exigir(
          await tx.actualizar(
            'tickets',
            {
              'titulo': titulo.trim(),
              'descripcion': descripcion.trim(),
              'estado': estado,
              'scheduled_at': programado.toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              'sync_status': 'pending',
            },
            donde: 'id_local = ? AND usuario_id = ?',
            argumentos: [id, usuario],
          ),
        );
        if (n != 1) throw StateError('Ticket no autorizado.');
        OperacionesSqlite.exigir(
          await RepositorioCola(tx).agregarPendiente(
            usuarioId: usuario,
            recurso: 'tickets',
            operacion: TipoOperacionLocal.actualizar,
            payload: {'id_local': id},
          ),
        );
      }),
    );
  }

  /// Completa únicamente Id remoto y estado local junto a confirmación de cola.
  /// Mantiene Id local y UUID originales; una interrupción revierte ambos cambios.
  Future<void> confirmar(
    int local,
    int remoto,
    int usuario,
    int operacion,
  ) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final otros = OperacionesSqlite.exigir(
          await RepositorioCola(tx).obtenerPendientes(usuarioId: usuario),
        );
        final pendiente = otros.any(
          (p) =>
              p.id != operacion &&
              p.recurso == 'tickets' &&
              p.payload['id_local'] == local,
        );
        final n = OperacionesSqlite.exigir(
          await tx.actualizar(
            'tickets',
            {
              'id_remoto': remoto,
              'sync_status': pendiente ? 'pending' : 'synced',
            },
            donde: 'id_local = ? AND usuario_id = ?',
            argumentos: [local, usuario],
          ),
        );
        if (n != 1) throw StateError('Ticket ausente.');
        OperacionesSqlite.exigir(
          await RepositorioCola(tx).marcarSincronizado(operacion),
        );
      }),
    );
  }

  /// Guarda descargas sin sobrescribir pending; reconcilia claves locales antes de insertar.
  Future<void> descargar(int usuario, List<dynamic> remotos) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        for (final r in remotos) {
          if (r['technicianId'] != usuario) {
            throw const FormatException('Autoría inválida.');
          }
          final filas = OperacionesSqlite.exigir(
            await tx.seleccionar(
              'tickets',
              donde:
                  'usuario_id = ? AND (id_remoto = ? OR (client_request_id IS NOT NULL AND client_request_id = ?))',
              argumentos: [usuario, r['id'], r['clientRequestId']],
            ),
          );
          if (filas.isNotEmpty && filas.single['sync_status'] == 'pending') {
            continue;
          }
          final datos = <String, Object?>{
            'id_remoto': r['id'] as int,
            'client_request_id': r['clientRequestId'] as String?,
            'usuario_id': usuario,
            'sucursal_id': r['branchId'] as int,
            'titulo': r['title'] as String,
            'descripcion': r['description'] as String,
            'estado': r['status'] as String,
            'created_at': DateTime.parse(
              r['createdAt'] as String,
            ).toUtc().toIso8601String(),
            'updated_at': DateTime.parse(
              r['updatedAt'] as String,
            ).toUtc().toIso8601String(),
            'scheduled_at': DateTime.parse(
              r['scheduledAt'] as String,
            ).toUtc().toIso8601String(),
            'sync_status': 'synced',
          };
          if (filas.isEmpty) {
            OperacionesSqlite.exigir(await tx.insertar('tickets', datos));
          } else {
            datos.remove('client_request_id');
            OperacionesSqlite.exigir(
              await tx.actualizar(
                'tickets',
                datos,
                donde: 'id_local = ?',
                argumentos: [filas.single['id_local']],
              ),
            );
          }
        }
      }),
    );
  }
}
