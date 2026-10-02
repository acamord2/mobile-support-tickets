/// Reconstruye un ticket exclusivamente desde SQLite manteniendo identidad local, remota, clave de reintento y programación independientes para agenda offline.
class TicketLocal {
  final int idLocal;
  final int? idRemoto;
  final String? clientRequestId;
  final int usuarioId;
  final int sucursalId;
  final int? reportanteId, tecnicoId;
  final String titulo, descripcion, estado, syncStatus;
  final DateTime creado, actualizado;
  final DateTime? programado;
  TicketLocal.desdeFila(Map<String, Object?> fila)
    : idLocal = fila['id_local'] as int,
      idRemoto = fila['id_remoto'] as int?,
      clientRequestId = fila['client_request_id'] as String?,
      usuarioId = fila['usuario_id'] as int,
      sucursalId = fila['sucursal_id'] as int,
      reportanteId = fila['reportante_id'] as int?,
      tecnicoId = fila['tecnico_id'] as int?,
      titulo = fila['titulo'] as String,
      descripcion = fila['descripcion'] as String,
      estado = fila['estado'] as String,
      syncStatus = fila['sync_status'] as String,
      creado = DateTime.parse(fila['created_at'] as String),
      actualizado = DateTime.parse(fila['updated_at'] as String),
      programado = fila['scheduled_at'] == null
          ? null
          : DateTime.parse(fila['scheduled_at'] as String);

  /// Serializa únicamente negocio y la clave original; no entrega sesión ni tokens.
  Map<String, Object?> paraCrear() => {
    'branchId': sucursalId,
    'title': titulo,
    'description': descripcion,
    'createdAt': creado.toUtc().toIso8601String(),
    'updatedAt': actualizado.toUtc().toIso8601String(),
    'scheduledAt': programado?.toUtc().toIso8601String(),
    'clientRequestId': clientRequestId,
  };
}
