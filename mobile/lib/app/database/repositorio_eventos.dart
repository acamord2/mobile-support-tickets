import '../../models/tipo_evento_ticket.dart';
import 'operaciones_sqlite.dart';
import 'repositorio_cola.dart';
import 'operacion_pendiente.dart';
import 'identificador_cliente.dart';
import 'repositorio_evidencias.dart';

/// Persiste instantáneas cronológicas con UUID estable y la cola técnica existente.
/// No contiene Base64: las imágenes se enlazan con evidencias del mismo ticket.
class RepositorioEventos {
  final OperacionesSqlite sql;
  RepositorioEventos(this.sql);

  /// Guarda seguimiento manual y foto opcional juntos; rechaza vacío o estado ajeno.
  Future<int> guardarSeguimiento(
    int ticket,
    int usuario,
    String descripcion, {
    String? autor,
    String? base64,
    String? mime,
  }) async {
    if (descripcion.trim().isEmpty && base64 == null) {
      throw StateError('Seguimiento vacío.');
    }
    return OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final filas = OperacionesSqlite.exigir(
          await tx.seleccionar(
            'tickets',
            donde: 'id_local = ? AND usuario_id = ? AND estado = ?',
            argumentos: [ticket, usuario, 'InProgress'],
          ),
        );
        if (filas.isEmpty) {
          throw StateError('Ticket no autorizado para seguimiento.');
        }
        final evidencia = base64 == null
            ? null
            : await RepositorioEvidencias(tx).crear(
                ticket,
                usuario,
                descripcion.trim().isEmpty
                    ? 'Fotografía del trabajo realizado'
                    : descripcion.trim(),
                base64: base64,
                mime: mime,
              );
        return RepositorioEventos(tx).agregar(
          ticket,
          usuario,
          TipoEventoTicket.seguimiento,
          descripcion.trim(),
          autor: autor,
          evidencia: evidencia,
        );
      }),
    );
  }

  /// Inserta evento+cola en el ejecutor recibido; negocio usa su misma transacción.
  Future<int> agregar(
    int ticket,
    int usuario,
    TipoEventoTicket tipo,
    String descripcion, {
    String? autor,
    String? fecha,
    DateTime? anterior,
    DateTime? programado,
    int? evidencia,
    String? clave,
    bool encolar = true,
  }) async {
    final id = OperacionesSqlite.exigir(
      await sql.insertar('ticket_eventos', {
        'ticket_id_local': ticket,
        'usuario_id': usuario,
        'autor_id': usuario,
        'usuario_nombre': autor,
        'tipo_evento': tipo.clave,
        'descripcion': descripcion,
        'created_at': fecha ?? DateTime.now().toUtc().toIso8601String(),
        'client_request_id': clave ?? IdentificadorCliente.crear(),
        'previous_scheduled_at': anterior?.toUtc().toIso8601String(),
        'scheduled_at': programado?.toUtc().toIso8601String(),
        'evidencia_id_local': evidencia,
        'sync_status': 'pending',
      }),
    );
    if (encolar) {
      OperacionesSqlite.exigir(
        await RepositorioCola(sql).agregarPendiente(
          usuarioId: usuario,
          recurso: 'eventos',
          operacion: TipoOperacionLocal.crear,
          payload: {'id_local': id},
        ),
      );
    }
    return id;
  }

  /// Lista eventos propios y fotografía enlazada, sin depender de la sesión actual.
  Future<List<Map<String, Object?>>> listar(
    int ticket,
    int usuario,
  ) async => OperacionesSqlite.exigir(
    await sql.seleccionar(
      'ticket_eventos e LEFT JOIN evidencias v ON v.id_local = e.evidencia_id_local AND v.usuario_id = e.usuario_id',
      columnas: ['e.*', 'v.photo_base64'],
      donde: 'e.ticket_id_local = ? AND e.usuario_id = ?',
      argumentos: [ticket, usuario],
      orden: 'e.created_at, e.id_local',
    ),
  );

  /// Obtiene evento de cola por propietario; su contenido no cambia con el ticket.
  Future<Map<String, Object?>?> obtener(int id, int usuario) async {
    final filas = OperacionesSqlite.exigir(
      await sql.seleccionar(
        'ticket_eventos',
        donde: 'id_local = ? AND usuario_id = ?',
        argumentos: [id, usuario],
      ),
    );
    return filas.isEmpty ? null : filas.single;
  }

  /// Confirma Id remoto y operación juntos manteniendo UUID, autor y hora originales.
  Future<void> confirmar(int id, int remoto, int usuario, int operacion) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        OperacionesSqlite.exigir(
          await tx.actualizar(
            'ticket_eventos',
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

  /// Reconciliación por UUID/Id remoto: descargas nunca pisan eventos pendientes.
  Future<void> descargar(int ticket, int usuario, List datos) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        for (final dato in datos) {
          final e = Map<String, dynamic>.from(dato as Map);
          final filas = OperacionesSqlite.exigir(
            await tx.seleccionar(
              'ticket_eventos',
              donde:
                  'usuario_id = ? AND (id_remoto = ? OR client_request_id = ?)',
              argumentos: [usuario, e['id'], e['clientRequestId']],
            ),
          );
          if (filas.isNotEmpty) {
            if (filas.single['sync_status'] == 'synced') {
              OperacionesSqlite.exigir(
                await tx.actualizar(
                  'ticket_eventos',
                  {'id_remoto': e['id'], 'descripcion': e['description']},
                  donde: 'id_local = ?',
                  argumentos: [filas.single['id_local']],
                ),
              );
            }
            continue;
          }
          int? evidencia;
          if (e['evidenceId'] != null) {
            final fotos = OperacionesSqlite.exigir(
              await tx.seleccionar(
                'evidencias',
                donde:
                    'id_remoto = ? AND usuario_id = ? AND ticket_id_local = ?',
                argumentos: [e['evidenceId'], usuario, ticket],
              ),
            );
            if (fotos.isNotEmpty) evidencia = fotos.single['id_local'] as int;
          }
          OperacionesSqlite.exigir(
            await tx.insertar('ticket_eventos', {
              'id_remoto': e['id'],
              'ticket_id_local': ticket,
              'usuario_id': usuario,
              'autor_id': e['userId'],
              'usuario_nombre': e['userName'],
              'tipo_evento': e['eventType'],
              'descripcion': e['description'],
              'created_at': DateTime.parse(
                e['createdAt'] as String,
              ).toUtc().toIso8601String(),
              'client_request_id': e['clientRequestId'],
              'previous_scheduled_at': e['previousScheduledAt'] == null
                  ? null
                  : DateTime.parse(
                      e['previousScheduledAt'] as String,
                    ).toUtc().toIso8601String(),
              'scheduled_at': e['scheduledAt'] == null
                  ? null
                  : DateTime.parse(
                      e['scheduledAt'] as String,
                    ).toUtc().toIso8601String(),
              'evidencia_id_local': evidencia,
              'sync_status': 'synced',
            }),
          );
        }
      }),
    );
  }
}
