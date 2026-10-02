import 'operaciones_sqlite.dart';
import 'repositorio_cola.dart';
import 'operacion_pendiente.dart';

/// Guarda evidencia y cola juntas sin bloquear captura offline ni perder autoría.
class RepositorioEvidencias {
  final OperacionesSqlite sql;
  RepositorioEvidencias(this.sql);

  /// Lista seguimiento propio por ticket y fecha desde SQLite para consulta offline.
  Future<List<Map<String, Object?>>> listar(int ticket, int usuario) async =>
      OperacionesSqlite.exigir(
        await sql.seleccionar(
          'evidencias',
          donde: 'ticket_id_local = ? AND usuario_id = ?',
          argumentos: [ticket, usuario],
          orden: 'created_at, id_local',
        ),
      );

  /// Descarga evidencias remotas sin duplicar las ya confirmadas ni tocar pendientes.
  Future<void> descargar(int ticket, int usuario, List datos) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        for (final dato in datos) {
          final e = Map<String, dynamic>.from(dato as Map);
          final existentes = OperacionesSqlite.exigir(
            await tx.seleccionar(
              'evidencias',
              donde: 'id_remoto = ? AND usuario_id = ?',
              argumentos: [e['id'], usuario],
            ),
          );
          if (existentes.isNotEmpty) continue;
          OperacionesSqlite.exigir(
            await tx.insertar('evidencias', {
              'ticket_id_local': ticket,
              'usuario_id': usuario,
              'id_remoto': e['id'],
              'descripcion': e['description'],
              'created_at': e['createdAt'],
              'photo_base64': e['photoBase64'],
              'mime': e['photoBase64'] == null ? null : 'image/jpeg',
              'sync_status': 'synced',
            }),
          );
        }
      }),
    );
  }

  Future<int> crear(
    int ticket,
    int usuario,
    String descripcion, {
    String? base64,
    String? mime,
  }) async => OperacionesSqlite.exigir(
    await sql.transaccion((tx) async {
      final filas = OperacionesSqlite.exigir(
        await tx.seleccionar(
          'tickets',
          donde: 'id_local = ? AND usuario_id = ?',
          argumentos: [ticket, usuario],
        ),
      );
      if (filas.isEmpty) throw StateError('Ticket no autorizado.');
      final id = OperacionesSqlite.exigir(
        await tx.insertar('evidencias', {
          'ticket_id_local': ticket,
          'usuario_id': usuario,
          'descripcion': descripcion.trim(),
          'photo_base64': base64,
          'mime': mime,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'sync_status': 'pending',
        }),
      );
      OperacionesSqlite.exigir(
        await RepositorioCola(tx).agregarPendiente(
          usuarioId: usuario,
          recurso: 'evidencias',
          operacion: TipoOperacionLocal.crear,
          payload: {'id_local': id},
        ),
      );
      return id;
    }),
  );

  /// Consulta evidencia propia para envío, sin almacenar su contenido pesado en la cola.
  Future<Map<String, Object?>?> obtener(int id, int usuario) async {
    final filas = OperacionesSqlite.exigir(
      await sql.seleccionar(
        'evidencias',
        donde: 'id_local = ? AND usuario_id = ?',
        argumentos: [id, usuario],
      ),
    );
    return filas.isEmpty ? null : filas.single;
  }

  /// Confirma evidencia y cola atómicamente para no recrear el ticket si falla su envío.
  Future<void> confirmar(int id, int remoto, int usuario, int operacion) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        OperacionesSqlite.exigir(
          await tx.actualizar(
            'evidencias',
            {'id_remoto': remoto, 'sync_status': 'synced'},
            donde: 'id_local = ? AND usuario_id = ?',
            argumentos: [id, usuario],
          ),
        );
        OperacionesSqlite.exigir(
          await RepositorioCola(tx).marcarSincronizado(operacion),
        );
      }),
    );
  }
}
