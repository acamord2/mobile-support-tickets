import 'package:sqflite/sqflite.dart';
import 'estado_sincronizacion.dart';

/// Define únicamente el esquema técnico local, sin tablas de negocio ni PostgreSQL.
/// Es la fuente de creación de SQLite para mantener SQL fuera de la presentación.
abstract class EsquemaSqlite {
  static const cola = 'cola_sincronizacion';

  /// Crea la cola una sola vez dentro de la transacción onCreate de sqflite.
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
  }

  /// Impide una actualización desconocida en vez de borrar la base o sus datos.
  /// Al introducir versión 2 se reemplazará por migraciones incrementales reales.
  static Future<void> actualizar(Database db, int anterior, int nueva) async {
    throw UnsupportedError(
      'La migración local solicitada no está implementada.',
    );
  }
}
