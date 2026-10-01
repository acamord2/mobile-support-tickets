import 'dart:convert';
import 'estado_sincronizacion.dart';

/// Identifica las modificaciones locales que podrán enviarse en etapas posteriores.
/// Se serializa por nombre sin incluir rutas HTTP ni verbos dentro de la UI.
enum TipoOperacionLocal { crear, actualizar, eliminar }

/// Representa una fila técnica de cola con payload JSON y metadatos de reintento.
/// No incluye sesión, token ni credenciales; el repositorio valida su persistencia.
class OperacionPendiente {
  final int id;
  final int? usuarioId;
  final String recurso;
  final TipoOperacionLocal operacion;
  final Map<String, Object?> payload;
  final DateTime creadoEn;
  final EstadoSincronizacion estado;
  final int intentos;
  final String? ultimoError;

  /// Reconstruye una fila SQLite mediante enum, fecha UTC y JSON controlado.
  /// El mapeo vive junto al modelo técnico, fuera de módulos y presentación.
  OperacionPendiente.desdeFila(Map<String, Object?> fila)
    : id = fila['id'] as int,
      usuarioId = fila['usuario_id'] as int?,
      recurso = fila['recurso'] as String,
      operacion = TipoOperacionLocal.values.byName(fila['operacion'] as String),
      payload = Map<String, Object?>.from(
        jsonDecode(fila['payload'] as String) as Map,
      ),
      creadoEn = DateTime.parse(fila['creado_en'] as String),
      estado = EstadoSincronizacion.values.byName(fila['estado'] as String),
      intentos = fila['intentos'] as int,
      ultimoError = fila['ultimo_error'] as String?;
}
