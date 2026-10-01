import 'dart:async';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'configuracion_sqlite.dart';
import 'esquema_sqlite.dart';

/// Centraliza apertura, versión y cierre de SQLite con una única conexión diferida.
/// Comparte la apertura entre solicitudes concurrentes; fábrica/ruta inyectables
/// permiten probar SQLite real en memoria o en archivo sin abrirlo desde módulos.
class ConexionSqlite extends GetxService {
  final DatabaseFactory _fabrica;
  final String? _ruta;
  Future<Database>? _apertura;

  /// Recibe adaptadores opcionales solo para tests y usa sqflite en el teléfono.
  /// No abre ni crea archivos hasta la primera operación local.
  ConexionSqlite({DatabaseFactory? fabrica, String? ruta})
    : _fabrica = fabrica ?? databaseFactory,
      _ruta = ruta;

  /// Abre o reutiliza la base y aplica su esquema/versionado sin borrar datos.
  /// Si falla, permite una apertura posterior sin conservar un Future fallido.
  Future<Database> _abrir() async {
    final apertura = _apertura ??= _crearConexion();
    try {
      return await apertura;
    } catch (_) {
      if (identical(_apertura, apertura)) _apertura = null;
      rethrow;
    }
  }

  /// Resuelve la ruta privada y registra creación/migración del esquema técnico.
  /// Una versión inferior tampoco puede recrearse destructivamente.
  Future<Database> _crearConexion() async {
    final ruta =
        _ruta ??
        path.join(
          await _fabrica.getDatabasesPath(),
          ConfiguracionSqlite.nombre,
        );
    return _fabrica.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: ConfiguracionSqlite.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: EsquemaSqlite.crear,
        onUpgrade: EsquemaSqlite.actualizar,
      ),
    );
  }

  /// Ejecuta un callback controlado usado exclusivamente por la abstracción local.
  /// No expone una conexión almacenada a vistas o controllers funcionales.
  Future<T> ejecutar<T>(Future<T> Function(DatabaseExecutor) accion) async =>
      accion(await _abrir());

  /// Agrupa cambios y cola en una transacción para evitar escrituras parciales.
  /// Un fallo revierte todas sus operaciones usando el Transaction del paquete.
  Future<T> transaccion<T>(Future<T> Function(DatabaseExecutor) accion) async =>
      (await _abrir()).transaction(accion);

  /// Espera cualquier apertura y cierra explícitamente sin eliminar el archivo.
  /// Debe invocarse al terminar consumidores, nunca en medio de sus operaciones.
  Future<void> cerrar() async {
    final apertura = _apertura;
    if (apertura == null) return;
    try {
      await (await apertura).close();
    } finally {
      if (identical(_apertura, apertura)) _apertura = null;
    }
  }

  /// Vincula el cierre al ciclo de vida global y consume posibles fallos de cierre.
  /// Evita excepciones técnicas no controladas cuando GetX libera el servicio.
  @override
  void onClose() {
    unawaited(cerrar().catchError((Object _) {}));
    super.onClose();
  }
}
