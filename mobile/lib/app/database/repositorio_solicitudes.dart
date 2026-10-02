import '../../models/tipo_solicitud_estado.dart';
import '../../models/tipo_evento_ticket.dart';
import 'operaciones_sqlite.dart';
import 'repositorio_tickets.dart';
import 'repositorio_eventos.dart';
import 'repositorio_cola.dart';
import 'operacion_pendiente.dart';
import 'identificador_cliente.dart';

/// Conserva workflow y eventos locales en la transacción de negocio y utiliza la única cola existente.
class RepositorioSolicitudes {
  final OperacionesSqlite sql;
  RepositorioSolicitudes(this.sql);

  /// Lista únicamente solicitudes de tickets visibles para esta cuenta y permite leer decisiones históricas.
  Future<List<Map<String, Object?>>> listar(
    int usuario, {
    int? ticket,
    bool pendientes = false,
  }) async => OperacionesSqlite.exigir(
    await sql.seleccionar(
      'ticket_status_requests s JOIN tickets t ON t.id_local=s.ticket_id_local AND t.usuario_id=s.usuario_id',
      columnas: ['s.*', 't.titulo'],
      donde:
          's.usuario_id = ? AND t.visible = 1${ticket == null ? '' : ' AND s.ticket_id_local = ?'}${pendientes ? " AND s.estado = 'PENDIENTE'" : ''}',
      argumentos: [usuario, ?ticket],
      orden: 's.created_at,s.id_local',
    ),
  );

  /// Obtiene una identidad propia de la cola sin permitir que otra sesión utilice la operación.
  Future<Map<String, Object?>?> obtener(int id, int usuario) async {
    final filas = OperacionesSqlite.exigir(
      await sql.seleccionar(
        'ticket_status_requests',
        donde: 'id_local = ? AND usuario_id = ?',
        argumentos: [id, usuario],
      ),
    );
    return filas.isEmpty ? null : filas.single;
  }

  /// Crea una solicitud y evento sin alterar estado del ticket; bloquea duplicados pendientes del mismo tipo.
  Future<int> crear(
    int ticket,
    int usuario,
    int rol,
    String autor,
    TipoSolicitudEstado tipo,
    String? motivo,
  ) async {
    if (tipo == TipoSolicitudEstado.cancelacion &&
        (motivo?.trim().isEmpty ?? true)) {
      throw StateError('Escribe el motivo de cancelación.');
    }
    return OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final t = await RepositorioTickets(tx).obtener(ticket, usuario);
        if (t == null ||
            t.estado == 'Resolved' ||
            t.estado == 'Cancelled' ||
            !(rol == 1 ||
                (rol == 4 && t.reportanteId == usuario) ||
                ((rol == 2 || rol == 3) && t.tecnicoId == usuario))) {
          throw StateError('Solicitud no autorizada.');
        }
        if ((await RepositorioSolicitudes(tx).listar(
          usuario,
          ticket: ticket,
          pendientes: true,
        )).any((s) => s['tipo'] == tipo.clave)) {
          throw StateError('Ya existe una solicitud pendiente de este tipo.');
        }
        final clave = IdentificadorCliente.crear(),
            evento = IdentificadorCliente.crear();
        final fecha = DateTime.now().toUtc().toIso8601String();
        final id = OperacionesSqlite.exigir(
          await tx.insertar('ticket_status_requests', {
            'ticket_id_local': ticket,
            'usuario_id': usuario,
            'requester_user_id': usuario,
            'requester_name': autor,
            'tipo': tipo.clave,
            'motivo': motivo?.trim(),
            'estado': EstadoSolicitud.pendiente.clave,
            'created_at': fecha,
            'client_request_id': clave,
            'sync_status': 'pending',
          }),
        );
        await RepositorioEventos(tx).agregar(
          ticket,
          usuario,
          tipo == TipoSolicitudEstado.resolucion
              ? TipoEventoTicket.solicitudResolucion
              : TipoEventoTicket.solicitudCancelacion,
          'Solicitud de ${tipo.texto.toLowerCase()}: ${motivo?.trim() ?? "Sin comentario"}',
          autor: autor,
          fecha: fecha,
          clave: evento,
          encolar: false,
        );
        OperacionesSqlite.exigir(
          await RepositorioCola(tx).agregarPendiente(
            usuarioId: usuario,
            recurso: 'solicitudes',
            operacion: TipoOperacionLocal.crear,
            payload: {
              'id_local': id,
              'eventClientRequestId': evento,
              'eventos': [evento],
            },
          ),
        );
        return id;
      }),
    );
  }

  /// Guarda revisión y, solo al aprobar, estado final; conserva autoría y eventos con claves estables en la cola.
  Future<void> revisar(
    int id,
    int usuario,
    int rol,
    String autor,
    bool aprobar,
  ) async {
    if (rol != 1 && rol != 3) {
      throw StateError('Solo coordinación puede revisar.');
    }
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final s = await RepositorioSolicitudes(tx).obtener(id, usuario);
        if (s == null || s['estado'] != EstadoSolicitud.pendiente.clave) {
          throw StateError('Solicitud ya revisada.');
        }
        final t = await RepositorioTickets(
          tx,
        ).obtener(s['ticket_id_local'] as int, usuario);
        if (t == null ||
            (aprobar && (t.estado == 'Resolved' || t.estado == 'Cancelled'))) {
          throw StateError('Ticket finalizado.');
        }
        final estado = aprobar
            ? EstadoSolicitud.aprobada
            : EstadoSolicitud.rechazada;
        final fecha = DateTime.now().toUtc().toIso8601String();
        final decision = IdentificadorCliente.crear(),
            finalClave = aprobar ? IdentificadorCliente.crear() : null;
        OperacionesSqlite.exigir(
          await tx.actualizar(
            'ticket_status_requests',
            {
              'estado': estado.clave,
              'reviewed_by_user_id': usuario,
              'reviewer_name': autor,
              'reviewed_at': fecha,
              'sync_status': 'pending',
            },
            donde: 'id_local = ? AND usuario_id = ?',
            argumentos: [id, usuario],
          ),
        );
        final resolucion = s['tipo'] == TipoSolicitudEstado.resolucion.clave;
        final evento = resolucion
            ? (aprobar
                  ? TipoEventoTicket.resolucionAprobada
                  : TipoEventoTicket.resolucionRechazada)
            : (aprobar
                  ? TipoEventoTicket.cancelacionAprobada
                  : TipoEventoTicket.cancelacionRechazada);
        final descripcion =
            'Solicitante #${s['requester_user_id']}, revisor #$usuario: ${estado.clave}';
        await RepositorioEventos(tx).agregar(
          t.idLocal,
          usuario,
          evento,
          descripcion,
          autor: autor,
          fecha: fecha,
          clave: decision,
          encolar: false,
        );
        if (aprobar) {
          OperacionesSqlite.exigir(
            await tx.actualizar(
              'tickets',
              {
                'estado': resolucion ? 'Resolved' : 'Cancelled',
                'updated_at': fecha,
                'sync_status': 'pending',
              },
              donde: 'id_local = ? AND usuario_id = ?',
              argumentos: [t.idLocal, usuario],
            ),
          );
          await RepositorioEventos(tx).agregar(
            t.idLocal,
            usuario,
            resolucion ? TipoEventoTicket.resuelto : TipoEventoTicket.cancelado,
            descripcion,
            autor: autor,
            fecha: fecha,
            clave: finalClave,
            encolar: false,
          );
        }
        OperacionesSqlite.exigir(
          await RepositorioCola(tx).agregarPendiente(
            usuarioId: usuario,
            recurso: 'solicitudes',
            operacion: TipoOperacionLocal.actualizar,
            payload: {
              'id_local': id,
              'status': estado.clave,
              'reviewedAt': fecha,
              'decisionClientRequestId': decision,
              'finalClientRequestId': finalClave,
              'eventos': [decision, ?finalClave],
            },
          ),
        );
      }),
    );
  }

  /// Confirma solicitud/eventos/cola conjuntamente; una interrupción conserva todos pendientes para reintentar.
  Future<void> confirmar(
    int local,
    int remoto,
    int usuario,
    int operacion,
    Map<String, Object?> payload,
  ) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final restantes = OperacionesSqlite.exigir(
          await RepositorioCola(tx).obtenerPendientes(usuarioId: usuario),
        );
        final pendiente = restantes.any(
          (p) =>
              p.id != operacion &&
              p.recurso == 'solicitudes' &&
              p.payload['id_local'] == local,
        );
        final s = (await RepositorioSolicitudes(tx).obtener(local, usuario))!;
        OperacionesSqlite.exigir(
          await tx.actualizar(
            'ticket_status_requests',
            {
              'id_remoto': remoto,
              'sync_status': pendiente ? 'pending' : 'synced',
            },
            donde: 'id_local = ? AND usuario_id = ?',
            argumentos: [local, usuario],
          ),
        );
        for (final clave in payload['eventos'] as List) {
          OperacionesSqlite.exigir(
            await tx.actualizar(
              'ticket_eventos',
              {'sync_status': 'synced'},
              donde: 'usuario_id = ? AND client_request_id = ?',
              argumentos: [usuario, clave],
            ),
          );
        }
        if (payload['status'] == EstadoSolicitud.aprobada.clave) {
          final t = (await RepositorioTickets(
            tx,
          ).obtener(s['ticket_id_local'] as int, usuario))!;
          await RepositorioTickets(
            tx,
          ).confirmar(t.idLocal, t.idRemoto!, usuario, operacion);
        } else {
          OperacionesSqlite.exigir(
            await RepositorioCola(tx).marcarSincronizado(operacion),
          );
        }
      }),
    );
  }

  /// Descarga solicitudes del alcance de la agenda; reconcilia UUID y respeta revisiones locales aún pendientes.
  Future<void> descargar(int usuario, List datos) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        for (final d in datos) {
          final tickets = OperacionesSqlite.exigir(
            await tx.seleccionar(
              'tickets',
              donde: 'usuario_id = ? AND id_remoto = ? AND visible = 1',
              argumentos: [usuario, d['ticketId']],
            ),
          );
          if (tickets.isEmpty) continue;
          final filas = OperacionesSqlite.exigir(
            await tx.seleccionar(
              'ticket_status_requests',
              donde:
                  'usuario_id = ? AND (id_remoto = ? OR client_request_id = ?)',
              argumentos: [usuario, d['id'], d['clientRequestId']],
            ),
          );
          if (filas.isNotEmpty && filas.single['sync_status'] == 'pending') {
            continue;
          }
          final valores = <String, Object?>{
            'id_remoto': d['id'],
            'ticket_id_local': tickets.single['id_local'],
            'usuario_id': usuario,
            'requester_user_id': d['requesterUserId'],
            'requester_name': d['requesterName'],
            'tipo': d['type'],
            'motivo': d['reason'],
            'estado': d['status'],
            'created_at': d['createdAt'],
            'reviewed_by_user_id': d['reviewedByUserId'],
            'reviewer_name': d['reviewerName'],
            'reviewed_at': d['reviewedAt'],
            'client_request_id': d['clientRequestId'],
            'sync_status': 'synced',
          };
          if (filas.isEmpty) {
            OperacionesSqlite.exigir(
              await tx.insertar('ticket_status_requests', valores),
            );
          } else {
            OperacionesSqlite.exigir(
              await tx.actualizar(
                'ticket_status_requests',
                valores,
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
