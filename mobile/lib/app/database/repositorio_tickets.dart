import '../../models/ticket_local.dart';
import 'operaciones_sqlite.dart';
import 'repositorio_cola.dart';
import 'operacion_pendiente.dart';
import 'identificador_cliente.dart';
import 'repositorio_eventos.dart';
import '../../models/tipo_evento_ticket.dart';

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
          donde: 'usuario_id = ? AND visible = 1',
          argumentos: [usuario],
          orden: 'scheduled_at, created_at, id_local',
        ),
      ).map(TicketLocal.desdeFila).toList();

  /// Localiza por Id local y propietario, sin permitir otra cuenta leer un ticket.
  Future<TicketLocal?> obtener(int id, int usuario) async {
    final filas = OperacionesSqlite.exigir(
      await sql.seleccionar(
        'tickets',
        donde: 'id_local = ? AND usuario_id = ? AND visible = 1',
        argumentos: [id, usuario],
      ),
    );
    return filas.isEmpty ? null : TicketLocal.desdeFila(filas.single);
  }

  /// Calcula el resumen desde registros locales sin inventar datos cuando no hay descarga.
  Future<Map<String, int>> conteos(int usuario) async {
    final total = {
      'Pending': 0,
      'InProgress': 0,
      'Resolved': 0,
      'Cancelled': 0,
    };
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
    required DateTime? programado,
    Map<String, Object?>? evidencia,
    String? autorNombre,
    int rol = 2,
  }) async {
    return OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final fecha = DateTime.now().toUtc().toIso8601String();
        final id = OperacionesSqlite.exigir(
          await tx.insertar('tickets', {
            'usuario_id': usuario,
            'reportante_id': usuario,
            'tecnico_id': rol == 2 ? usuario : null,
            'sucursal_id': sucursal,
            'titulo': titulo.trim(),
            'descripcion': descripcion.trim(),
            'estado': 'Pending',
            'created_at': fecha,
            'updated_at': fecha,
            'scheduled_at': programado?.toUtc().toIso8601String(),
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
        int? fotoInicial;
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
          fotoInicial = foto;
          OperacionesSqlite.exigir(
            await RepositorioCola(tx).agregarPendiente(
              usuarioId: usuario,
              recurso: 'evidencias',
              operacion: TipoOperacionLocal.crear,
              payload: {'id_local': foto, 'initial': true},
            ),
          );
        }
        final eventos = RepositorioEventos(tx);
        await eventos.agregar(
          id,
          usuario,
          TipoEventoTicket.creado,
          'Ticket registrado',
          evidencia: fotoInicial,
          autor: autorNombre,
          fecha: fecha,
        );
        if (programado != null) {
          await eventos.agregar(
            id,
            usuario,
            TipoEventoTicket.programado,
            'Atención programada',
            autor: autorNombre,
            fecha: fecha,
            programado: programado,
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
    required DateTime? programado,
    String? autorNombre,
  }) async {
    if (!['Pending', 'InProgress', 'Resolved'].contains(estado)) {
      throw const FormatException('Estado inválido.');
    }
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final previas = OperacionesSqlite.exigir(
          await tx.seleccionar(
            'tickets',
            donde: 'id_local = ? AND usuario_id = ?',
            argumentos: [id, usuario],
          ),
        );
        if (previas.isEmpty) throw StateError('Ticket no autorizado.');
        final previo = TicketLocal.desdeFila(previas.single);
        if (previo.estado == 'Resolved' || previo.estado == 'Cancelled') {
          throw StateError('Ticket resuelto.');
        }
        if (previo.estado != estado &&
            !((previo.estado == 'Pending' && estado == 'InProgress') ||
                (previo.estado == 'InProgress' && estado == 'Resolved'))) {
          throw StateError('Transición inválida.');
        }
        if (estado == 'Resolved' && previo.estado != estado) {
          throw StateError('Se requiere aprobación.');
        }
        final n = OperacionesSqlite.exigir(
          await tx.actualizar(
            'tickets',
            {
              'titulo': titulo.trim(),
              'descripcion': descripcion.trim(),
              'estado': estado,
              'scheduled_at': programado?.toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              'sync_status': 'pending',
            },
            donde: 'id_local = ? AND usuario_id = ?',
            argumentos: [id, usuario],
          ),
        );
        if (n != 1) throw StateError('Ticket no autorizado.');
        final eventos = RepositorioEventos(tx);
        if (previo.programado != programado) {
          await eventos.agregar(
            id,
            usuario,
            previo.programado == null
                ? TipoEventoTicket.programado
                : TipoEventoTicket.reprogramado,
            'Atención reprogramada',
            autor: autorNombre,
            anterior: previo.programado,
            programado: programado,
          );
        }
        if (previo.estado != estado) {
          final iniciado = estado == 'InProgress';
          await eventos.agregar(
            id,
            usuario,
            iniciado ? TipoEventoTicket.enAtencion : TipoEventoTicket.resuelto,
            iniciado ? 'Atención iniciada' : 'Ticket resuelto',
            autor: autorNombre,
          );
        }
        OperacionesSqlite.exigir(
          await RepositorioCola(tx).agregarPendiente(
            usuarioId: usuario,
            recurso: 'tickets',
            operacion: TipoOperacionLocal.actualizar,
            payload: {
              'id_local': id,
              'title': titulo.trim(),
              'description': descripcion.trim(),
              'status': estado,
              'scheduledAt': programado?.toUtc().toIso8601String(),
            },
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
              (p.recurso == 'tickets' || p.recurso == 'asignaciones') &&
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
  Future<void> descargar(
    int usuario,
    List<dynamic> remotos, {
    int rol = 2,
    Set<int> tecnicos = const {},
  }) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final visibles = remotos.map((r) => r['id'] as int).toSet();
        final anteriores = OperacionesSqlite.exigir(
          await tx.seleccionar(
            'tickets',
            donde: 'usuario_id = ?',
            argumentos: [usuario],
          ),
        );
        for (final fila in anteriores) {
          if (fila['id_remoto'] != null &&
              fila['sync_status'] == 'synced' &&
              !visibles.contains(fila['id_remoto'])) {
            OperacionesSqlite.exigir(
              await tx.actualizar(
                'tickets',
                {'visible': 0},
                donde: 'id_local = ?',
                argumentos: [fila['id_local']],
              ),
            );
          }
        }
        for (final r in remotos) {
          if ((rol == 2 && r['technicianId'] != usuario) ||
              (rol == 4 && r['reporterUserId'] != usuario) ||
              (rol == 3 &&
                  r['technicianId'] != null &&
                  r['technicianId'] != usuario &&
                  !tecnicos.contains(r['technicianId']))) {
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
            'reportante_id': r['reporterUserId'] as int?,
            'tecnico_id': r['technicianId'] as int?,
            'visible': 1,
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
            'scheduled_at': r['scheduledAt'] == null
                ? null
                : DateTime.parse(
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
