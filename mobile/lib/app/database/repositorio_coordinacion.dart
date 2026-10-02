import 'operaciones_sqlite.dart';
import 'repositorio_tickets.dart';
import 'repositorio_eventos.dart';
import 'repositorio_cola.dart';
import 'operacion_pendiente.dart';
import '../../models/tipo_evento_ticket.dart';

/// Conserva equipo autorizado para coordinación offline y asignaciones con instantáneas de historia.
class RepositorioCoordinacion {
  final OperacionesSqlite sql;
  RepositorioCoordinacion(this.sql);

  /// Consulta únicamente el catálogo descargado para esta cuenta, no técnicos de otras sesiones.
  Future<List<Map<String, Object?>>> listar(int usuario) async =>
      OperacionesSqlite.exigir(
        await sql.seleccionar(
          'tecnicos',
          donde: 'usuario_id = ?',
          argumentos: [usuario],
          orden: 'nombre,id',
        ),
      );

  /// Reemplaza catálogo de alcance actual sin tocar tickets, historia ni cola pendientes.
  Future<void> guardar(int usuario, List datos) async {
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        OperacionesSqlite.exigir(
          await tx.eliminar(
            'tecnicos',
            donde: 'usuario_id = ?',
            argumentos: [usuario],
          ),
        );
        for (final dato in datos) {
          OperacionesSqlite.exigir(
            await tx.insertar('tecnicos', {
              'usuario_id': usuario,
              'id': dato['id'],
              'nombre': dato['name'],
              'coordinador_id': dato['coordinatorUserId'],
            }),
          );
        }
      }),
    );
  }

  /// Guarda técnico, operación y evento juntos; la API volverá a comprobar relación y estado real.
  Future<void> asignar(
    int ticket,
    int usuario,
    int rol,
    int tecnico,
    String autor,
  ) async {
    if (rol != 1 && rol != 3) throw StateError('Rol no autorizado.');
    OperacionesSqlite.exigir(
      await sql.transaccion((tx) async {
        final actual = await RepositorioTickets(tx).obtener(ticket, usuario);
        final equipo = (await RepositorioCoordinacion(tx).listar(usuario)).toList();
        if (rol == 3) {
          equipo.add({
            'id': usuario,
            'nombre': autor,
            'coordinador_id': usuario,
          });
        }
        if (actual == null ||
            (actual.estado == 'Resolved' || actual.estado == 'Cancelled')) {
          throw StateError('Ticket no asignable.');
        }
        final destinos = equipo.where((t) => t['id'] == tecnico).toList();
        if (destinos.length != 1 ||
            (rol == 3 && destinos.single['coordinador_id'] != usuario)) {
          throw StateError('Técnico no autorizado.');
        }
        if (rol == 3 &&
            actual.tecnicoId != null &&
            !equipo.any((t) => t['id'] == actual.tecnicoId)) {
          throw StateError('Ticket fuera del equipo.');
        }
        if (actual.tecnicoId == tecnico) return;
        final anteriores = equipo
            .where((t) => t['id'] == actual.tecnicoId)
            .toList();
        final anterior = anteriores.isEmpty
            ? 'Técnico #${actual.tecnicoId}'
            : '${anteriores.single['nombre']} (#${actual.tecnicoId})';
        final nuevo = '${destinos.single['nombre']} (#$tecnico)';
        OperacionesSqlite.exigir(
          await tx.actualizar(
            'tickets',
            {
              'tecnico_id': tecnico,
              'sync_status': 'pending',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            donde: 'id_local = ? AND usuario_id = ?',
            argumentos: [ticket, usuario],
          ),
        );
        OperacionesSqlite.exigir(
          await RepositorioCola(tx).agregarPendiente(
            usuarioId: usuario,
            recurso: 'asignaciones',
            operacion: TipoOperacionLocal.actualizar,
            payload: {'id_local': ticket, 'tecnico_id': tecnico},
          ),
        );
        await RepositorioEventos(tx).agregar(
          ticket,
          usuario,
          actual.tecnicoId == null
              ? TipoEventoTicket.asignado
              : TipoEventoTicket.reasignado,
          actual.tecnicoId == null
              ? 'Técnico asignado: $nuevo'
              : 'De: $anterior. A: $nuevo',
          autor: autor,
        );
      }),
    );
  }
}
