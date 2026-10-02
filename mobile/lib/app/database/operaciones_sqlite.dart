import 'package:sqflite/sqflite.dart';
import '../constants/textos_app.dart';
import 'conexion_sqlite.dart';
import 'resultado_sqlite.dart';

/// Reutiliza SELECT/INSERT/UPDATE/DELETE parametrizados y transacciones locales.
class OperacionesSqlite {
  final ConexionSqlite? _conexion;
  final DatabaseExecutor? _ejecutor;

  OperacionesSqlite(ConexionSqlite conexion)
    : _conexion = conexion,
      _ejecutor = null;

  /// Usa exclusivamente el ejecutor transaccional para no provocar bloqueos.
  OperacionesSqlite._transaccion(this._ejecutor) : _conexion = null;

  /// Delega al ejecutor activo, reutilizando la conexión cuando no hay transacción.
  Future<T> _ejecutar<T>(Future<T> Function(DatabaseExecutor) accion) =>
      _ejecutor == null ? _conexion!.ejecutar(accion) : accion(_ejecutor);

  /// Consulta filas usando argumentos enlazados, columnas y orden del repositorio.
  Future<ResultadoSqlite<List<Map<String, Object?>>>> seleccionar(
    String tabla, {
    List<String>? columnas,
    String? donde,
    List<Object?>? argumentos,
    String? orden,
  }) => controlar(
    () => _ejecutar(
      (db) => db.query(
        tabla,
        columns: columnas,
        where: donde,
        whereArgs: argumentos,
        orderBy: orden,
      ),
    ),
  );

  /// Inserta valores enlazados y devuelve el identificador local asignado.
  Future<ResultadoSqlite<int>> insertar(
    String tabla,
    Map<String, Object?> valores,
  ) => controlar(() => _ejecutar((db) => db.insert(tabla, valores)));

  /// Actualiza filas explícitamente filtradas para impedir cambios globales casuales.
  Future<ResultadoSqlite<int>> actualizar(
    String tabla,
    Map<String, Object?> valores, {
    required String donde,
    required List<Object?> argumentos,
  }) => controlar(
    () => _ejecutar(
      (db) => db.update(tabla, valores, where: donde, whereArgs: argumentos),
    ),
  );

  /// Elimina filas por condición parametrizada sin interpolar valores del usuario.
  Future<ResultadoSqlite<int>> eliminar(
    String tabla, {
    required String donde,
    required List<Object?> argumentos,
  }) => controlar(
    () => _ejecutar(
      (db) => db.delete(tabla, where: donde, whereArgs: argumentos),
    ),
  );

  /// Agrupa operaciones del repositorio usando una instancia ligada a Transaction.
  Future<ResultadoSqlite<T>> transaccion<T>(
    Future<T> Function(OperacionesSqlite) accion,
  ) => controlar(
    () => _conexion == null
        ? accion(this)
        : _conexion.transaccion(
            (db) => accion(OperacionesSqlite._transaccion(db)),
          ),
  );

  /// Convierte errores de ejecución/serialización a un resultado público genérico.
  static Future<ResultadoSqlite<T>> controlar<T>(
    Future<T> Function() accion,
  ) async {
    try {
      return ResultadoSqlite.exito(await accion());
    } catch (_) {
      return const ResultadoSqlite.error(TextosApp.errorSqlite);
    }
  }

  /// Los repositorios lo utilizan dentro de transacciones y al componer resultados.
  static T exigir<T>(ResultadoSqlite<T> resultado) {
    if (!resultado.exitoso) throw StateError(TextosApp.errorSqlite);
    return resultado.datos as T;
  }
}
