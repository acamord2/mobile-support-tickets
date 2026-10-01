import 'package:sqflite/sqflite.dart';
import 'estado_sincronizacion.dart';

/// Define cola técnica, identidad pública y tablas locales de tickets/evidencias.
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
    if (version >= 3) await _crearTickets(db);
  }

  /// Impide una actualización desconocida en vez de borrar la base o sus datos.
  /// Añade identidad en v2 conservando la cola y sus registros anteriores.
  static Future<void> actualizar(Database db, int anterior, int nueva) async {
    if (anterior < 2 && nueva >= 2) await _crearSesion(db);
    if (anterior < 3 && nueva >= 3) await _crearTickets(db);
    if (nueva > 3) throw UnsupportedError('Migración desconocida.');
  }

  /// Añade negocio y autoría en una sola migración conservando sesión y cola.
  /// Pendientes antiguos se asignan solo si existe identidad; los huérfanos siguen
  /// sin propietario y no se enviarán automáticamente bajo otra cuenta.
  static Future<void> _crearTickets(Database db) async {
    await db.execute('ALTER TABLE $sesion ADD COLUMN role_id INTEGER');
    await db.execute('ALTER TABLE $sesion ADD COLUMN rol TEXT');
    await db.execute('ALTER TABLE $cola ADD COLUMN usuario_id INTEGER');
    await db.execute(
      'UPDATE $cola SET usuario_id = (SELECT id_usuario FROM $sesion WHERE id = 1)',
    );
    await db.execute('''CREATE TABLE sucursales (
      id INTEGER NOT NULL, nombre TEXT NOT NULL, direccion TEXT NOT NULL,
      usuario_id INTEGER NOT NULL, PRIMARY KEY(id, usuario_id))''');
    await db.execute('''CREATE TABLE tickets (
      id_local INTEGER PRIMARY KEY AUTOINCREMENT, id_remoto INTEGER,
      client_request_id TEXT, usuario_id INTEGER NOT NULL,
      sucursal_id INTEGER NOT NULL, titulo TEXT NOT NULL, descripcion TEXT NOT NULL,
      estado TEXT NOT NULL CHECK(estado IN ('Pending','InProgress','Resolved')),
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL, scheduled_at TEXT NOT NULL,
      sync_status TEXT NOT NULL CHECK(sync_status IN ('synced','pending')),
      UNIQUE(usuario_id,id_remoto), UNIQUE(usuario_id,client_request_id))''');
    await db.execute('''CREATE TABLE evidencias (
      id_local INTEGER PRIMARY KEY AUTOINCREMENT, id_remoto INTEGER,
      ticket_id_local INTEGER NOT NULL, usuario_id INTEGER NOT NULL,
      descripcion TEXT NOT NULL, photo_base64 TEXT, mime TEXT,
      created_at TEXT NOT NULL, sync_status TEXT NOT NULL DEFAULT 'pending',
      FOREIGN KEY(ticket_id_local) REFERENCES tickets(id_local))''');
    await db.execute(
      'CREATE INDEX ix_agenda ON tickets(usuario_id,scheduled_at)',
    );
    await db.execute(
      'CREATE INDEX ix_cola_usuario ON $cola(usuario_id,estado)',
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
