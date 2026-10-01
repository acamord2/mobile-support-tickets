import '../../models/sesion_local.dart';
import '../../models/usuario.dart';
import '../services/almacenamiento_token.dart';
import 'esquema_sqlite.dart';
import 'operaciones_sqlite.dart';
import 'estado_sincronizacion.dart';

/// Persiste identidad en SQLite y JWT protegido sin modificar la cola.
/// Reutiliza el ejecutor común para mantener almacenamiento fuera de la presentación.
class RepositorioSesionLocal {
  final OperacionesSqlite _sql;
  final AlmacenamientoToken _tokens;

  /// Recibe infraestructura sustituible para probar sin plugins ni secretos reales.
  RepositorioSesionLocal(this._sql, this._tokens);

  /// Publica identidad después del token y elimina previamente la identidad anterior.
  /// Impide asociar un JWT nuevo al usuario anterior ante escrituras interrumpidas.
  Future<void> guardar(SesionLocal sesion) async {
    await _eliminarIdentidad();
    await _tokens.guardar(sesion.token!);
    try {
      OperacionesSqlite.exigir(
        await _sql.insertar(EsquemaSqlite.sesion, {
          'id': 1,
          'id_usuario': sesion.usuario.id,
          'username': sesion.usuario.username,
          'nombre': sesion.usuario.name,
          'role_id': sesion.usuario.roleId,
          'rol': sesion.usuario.role,
          'autenticado_en': sesion.autenticadoEn.toUtc().toIso8601String(),
          'expira_en': sesion.expiraEn?.toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      await _tokens.eliminar();
      rethrow;
    }
  }

  /// Restaura identidad sin API y admite JWT ausente para conservar trabajo offline.
  /// Limpia tokens huérfanos y valida los campos públicos sin inventar un usuario.
  Future<SesionLocal?> restaurar() async {
    final filas = OperacionesSqlite.exigir(
      await _sql.seleccionar(EsquemaSqlite.sesion),
    );
    if (filas.isEmpty) {
      await _tokens.eliminar();
      return null;
    }
    final fila = filas.single;
    final usuario = Usuario.fromJson({
      'id': fila['id_usuario'],
      'username': fila['username'],
      'name': fila['nombre'],
      'roleId': fila['role_id'],
      'role': fila['rol'],
    });
    return SesionLocal(
      usuario: usuario,
      token: await _tokens.leer(),
      autenticadoEn: DateTime.parse(fila['autenticado_en'] as String),
      expiraEn: fila['expira_en'] == null
          ? null
          : DateTime.parse(fila['expira_en'] as String),
    );
  }

  /// Retira solamente identidad y JWT para volver a Login sin borrar SQLite.
  Future<void> eliminar() async {
    await _eliminarIdentidad();
    await _tokens.eliminar();
  }

  /// Retira acceso remoto tras 401 conservando identidad y operaciones offline.
  Future<void> invalidarToken() => _tokens.eliminar();

  /// Comprueba toda operación no sincronizada, incluyendo procesando y error.
  /// Permite preservar pendientes al salir sin resolver todavía su futura autoría.
  Future<bool> hayPendientes() async => OperacionesSqlite.exigir(
    await _sql.seleccionar(
      EsquemaSqlite.cola,
      columnas: ['id'],
      donde: 'estado <> ?',
      argumentos: [EstadoSincronizacion.sincronizado.name],
    ),
  ).isNotEmpty;

  /// Elimina únicamente la fila de sesión con argumentos enlazados del ejecutor común.
  Future<void> _eliminarIdentidad() async {
    OperacionesSqlite.exigir(
      await _sql.eliminar(
        EsquemaSqlite.sesion,
        donde: 'id = ?',
        argumentos: [1],
      ),
    );
  }
}
