import 'package:sqflite/sqflite.dart';
import 'estado_sincronizacion.dart';

/// Define cola técnica e identidad pública local, sin Tickets ni PostgreSQL.
/// Es la fuente de creación de SQLite para mantener SQL fuera de la presentación.
abstract class EsquemaSqlite {
  static const cola = 'cola_sincronizacion';
  static const sesion = 'sesion_local';

  /// Crea cola e identidad pública dentro de la transacción onCreate de sqflite.
  /// Restringe estados e intentos para persistir operaciones pendientes coherentes.
  static Future<void> crear(Database db, int version) async {
    final estados = EstadoSincronizacion.values
        .map((e) => "'${e.name}'")
        .join(',');
    await db.execute('''
      CREATE TABLE $cola (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recurso TEXT NOT NULL,
        operacion TEXT NOT NULL,
        payload TEXT NOT NULL,
        creado_en TEXT NOT NULL,
        estado TEXT NOT NULL CHECK (estado IN ($estados)),
        intentos INTEGER NOT NULL DEFAULT 0 CHECK (intentos >= 0),
        ultimo_error TEXT
      )
    ''');
    if (version >= 2) await _crearSesion(db);
  }

  /// Impide una actualización desconocida en vez de borrar la base o sus datos.
  /// Añade identidad en v2 conservando la cola y sus registros anteriores.
  static Future<void> actualizar(Database db, int anterior, int nueva) async {
    if (anterior == 1 && nueva == 2) {
      await _crearSesion(db);
      return;
    }
    throw UnsupportedError(
      'La migración local solicitada no está implementada.',
    );
  }

  /// Crea una identidad única y fechas públicas para restaurar Home sin red.
  /// No incluye secretos: el JWT se mantiene en almacenamiento seguro.
  static Future<void> _crearSesion(Database db) => db.execute('''
    CREATE TABLE $sesion (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      id_usuario INTEGER NOT NULL,
      username TEXT NOT NULL,
      nombre TEXT NOT NULL,
      autenticado_en TEXT NOT NULL,
      expira_en TEXT
    )
  ''');
}
