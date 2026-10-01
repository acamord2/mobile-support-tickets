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
    if (version >= 4) await _crearEventos(db);
    if (version >= 5) await _crearRoles(db);
  }

  /// Impide una actualización desconocida en vez de borrar la base o sus datos.
  /// Añade identidad en v2 conservando la cola y sus registros anteriores.
  static Future<void> actualizar(Database db, int anterior, int nueva) async {
    if (anterior < 2 && nueva >= 2) await _crearSesion(db);
    if (anterior < 3 && nueva >= 3) await _crearTickets(db);
    if (anterior < 4 && nueva >= 4) await _crearEventos(db);
    if (anterior < 5 && nueva >= 5) await _crearRoles(db);
    if (nueva > 5) throw UnsupportedError('Migración desconocida.');
  }

  /// Añade alcance y equipo; copia íntegramente eventos al ampliar su CHECK dentro de la transacción de migración.
  /// Conserva claves, filas, evidencias, sesión y cola; no atribuye reportantes históricos desconocidos.
  static Future<void> _crearRoles(Database db) async {
    await db.execute('ALTER TABLE tickets ADD COLUMN reportante_id INTEGER');
    await db.execute('ALTER TABLE tickets ADD COLUMN tecnico_id INTEGER');
    await db.execute(
      'ALTER TABLE tickets ADD COLUMN visible INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute('UPDATE tickets SET tecnico_id=usuario_id');
    await db.execute('''CREATE TABLE tecnicos (
      usuario_id INTEGER NOT NULL, id INTEGER NOT NULL, nombre TEXT NOT NULL,
      coordinador_id INTEGER, PRIMARY KEY(usuario_id,id))''');
    final anteriores = (await db.rawQuery(
      'SELECT count(*) n FROM ticket_eventos',
    )).single['n'];
    await db.execute('ALTER TABLE ticket_eventos RENAME TO ticket_eventos_v4');
    await db.execute('DROP INDEX ix_eventos_ticket');
    await _crearEventos(db, roles: true);
    await db.execute(
      'INSERT INTO ticket_eventos SELECT * FROM ticket_eventos_v4',
    );
    if ((await db.rawQuery(
          'SELECT count(*) n FROM ticket_eventos',
        )).single['n'] !=
        anteriores) {
      throw StateError('No se conservaron los eventos.');
    }
    await db.execute('DROP TABLE ticket_eventos_v4');
  }

  /// Añade bitácora inmutable sin reconstruir historia desconocida ni borrar datos.
  /// Las referencias remotas se obtienen de ticket/evidencia, evitando duplicarlas.
  static Future<void> _crearEventos(Database db, {bool roles = false}) async {
    await db.execute('''CREATE TABLE ticket_eventos (
      id_local INTEGER PRIMARY KEY AUTOINCREMENT, id_remoto INTEGER,
      ticket_id_local INTEGER NOT NULL REFERENCES tickets(id_local),
      usuario_id INTEGER NOT NULL, autor_id INTEGER NOT NULL, usuario_nombre TEXT,
      tipo_evento TEXT NOT NULL CHECK(tipo_evento IN ('CREADO','PROGRAMADO','REPROGRAMADO','EN_ATENCION','SEGUIMIENTO','RESUELTO'${roles ? ",'ASIGNADO','REASIGNADO'" : ''})),
      descripcion TEXT NOT NULL, created_at TEXT NOT NULL, client_request_id TEXT NOT NULL,
      previous_scheduled_at TEXT, scheduled_at TEXT,
      evidencia_id_local INTEGER REFERENCES evidencias(id_local),
      sync_status TEXT NOT NULL CHECK(sync_status IN ('synced','pending')),
      UNIQUE(usuario_id,id_remoto), UNIQUE(usuario_id,client_request_id))''');
    await db.execute(
      'CREATE INDEX ix_eventos_ticket ON ticket_eventos(usuario_id,ticket_id_local,created_at,id_local)',
    );
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
