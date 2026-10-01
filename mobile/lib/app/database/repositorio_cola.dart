import 'dart:convert';
import 'esquema_sqlite.dart';
import 'estado_sincronizacion.dart';
import 'operaciones_sqlite.dart';
import 'operacion_pendiente.dart';
import 'resultado_sqlite.dart';

/// Clasifica errores persistibles sin guardar cuerpos API, exceptions o headers.
/// La cola conserva solo el nombre controlado para diagnosticar sin filtrar secretos.
enum ErrorSincronizacion { red, servidor, respuesta }

/// Administra la cola transversal usando únicamente la abstracción SQLite común.
/// Conoce campos y mapeo técnico; no conoce Tickets, endpoints ni widgets.
class RepositorioCola {
  final OperacionesSqlite _operaciones;

  /// Recibe operaciones normales o transaccionales para permitir cambios atómicos.
  /// Un repositorio futuro podrá guardar negocio y pendiente en la misma transacción.
  RepositorioCola(this._operaciones);

  /// Valida y serializa el payload como JSON y registra un pendiente con fecha UTC.
  /// Rechaza campos sensibles incluso anidados y valores Bearer/JWT antes de escribir.
  Future<ResultadoSqlite<int>> agregarPendiente({
    required String recurso,
    int? usuarioId,
    required TipoOperacionLocal operacion,
    required Map<String, Object?> payload,
  }) => OperacionesSqlite.controlar(() async {
    if (recurso.trim().isEmpty) {
      throw const FormatException('Recurso inválido.');
    }
    _validarSinSecretos(payload);
    return OperacionesSqlite.exigir(
      await _operaciones.insertar(EsquemaSqlite.cola, {
        'recurso': recurso.trim(),
        'usuario_id': usuarioId,
        'operacion': operacion.name,
        'payload': jsonEncode(payload),
        'creado_en': DateTime.now().toUtc().toIso8601String(),
        'estado': EstadoSincronizacion.pendiente.name,
        'intentos': 0,
      }),
    );
  });

  /// Lee pendientes y errores reintentables por id para preservar el orden local.
  /// No devuelve operaciones procesando ni sincronizadas como trabajo por enviar.
  Future<ResultadoSqlite<List<OperacionPendiente>>> obtenerPendientes({
    int? usuarioId,
  }) => OperacionesSqlite.controlar(() async {
    final filas = OperacionesSqlite.exigir(
      await _operaciones.seleccionar(
        EsquemaSqlite.cola,
        donde:
            'estado IN (?, ?)${usuarioId == null ? '' : ' AND usuario_id = ?'}',
        argumentos: [
          EstadoSincronizacion.pendiente.name,
          EstadoSincronizacion.error.name,
          ?usuarioId,
        ],
        orden: 'id ASC',
      ),
    );
    return filas.map(OperacionPendiente.desdeFila).toList();
  });

  /// Reclama un pendiente/error e incrementa intentos atómicamente antes del envío.
  /// Una transición inválida falla sin modificar una operación ya completada.
  Future<ResultadoSqlite<int>> marcarProcesando(int id) =>
      _operaciones.transaccion((operaciones) async {
        final filas = OperacionesSqlite.exigir(
          await operaciones.seleccionar(
            EsquemaSqlite.cola,
            donde: 'id = ? AND estado IN (?, ?)',
            argumentos: [
              id,
              EstadoSincronizacion.pendiente.name,
              EstadoSincronizacion.error.name,
            ],
          ),
        );
        if (filas.isEmpty) throw StateError('Operación no disponible.');
        return OperacionesSqlite.exigir(
          await operaciones.actualizar(
            EsquemaSqlite.cola,
            {
              'estado': EstadoSincronizacion.procesando.name,
              'intentos': (filas.single['intentos'] as int) + 1,
              'ultimo_error': null,
            },
            donde: 'id = ?',
            argumentos: [id],
          ),
        );
      });

  /// Recupera operaciones interrumpidas del propietario al iniciar un ciclo exclusivo.
  /// Conserva claves y payload para reintentar después de cerrar la aplicación.
  Future<ResultadoSqlite<int>> recuperar(int usuario) =>
      _operaciones.actualizar(
        EsquemaSqlite.cola,
        {'estado': EstadoSincronizacion.pendiente.name},
        donde: 'usuario_id = ? AND estado = ?',
        argumentos: [usuario, EstadoSincronizacion.procesando.name],
      );

  /// Confirma solo una operación procesando y conserva su fila como sincronizada.
  /// No elimina historial técnico ni presupone que un envío sin respuesta fue exitoso.
  Future<ResultadoSqlite<int>> marcarSincronizado(int id) =>
      _terminar(id, EstadoSincronizacion.sincronizado);

  /// Registra un error controlado, conservando el payload para un reintento explícito.
  Future<ResultadoSqlite<int>> marcarError(int id, ErrorSincronizacion error) =>
      _terminar(id, EstadoSincronizacion.error, error: error);

  /// Devuelve a pendiente cuando falla la red sin perder el trabajo o sus intentos.
  /// No implementa reintentos automáticos ni decide conflictos de negocio.
  Future<ResultadoSqlite<int>> devolverPendiente(int id) => _terminar(
    id,
    EstadoSincronizacion.pendiente,
    error: ErrorSincronizacion.red,
  );

  /// Aplica una transición filtrada para que un estado final no se sobrescriba.
  Future<ResultadoSqlite<int>> _terminar(
    int id,
    EstadoSincronizacion estado, {
    ErrorSincronizacion? error,
  }) => OperacionesSqlite.controlar(() async {
    final cantidad = OperacionesSqlite.exigir(
      await _operaciones.actualizar(
        EsquemaSqlite.cola,
        {'estado': estado.name, 'ultimo_error': error?.name},
        donde: 'id = ? AND estado = ?',
        argumentos: [id, EstadoSincronizacion.procesando.name],
      ),
    );
    if (cantidad != 1) throw StateError('Transición local inválida.');
    return cantidad;
  });

  /// Inspecciona mapas/listas y strings antes de serializar para excluir credenciales.
  /// Es una defensa adicional; los repositorios futuros deben enviar solo campos de negocio.
  static void _validarSinSecretos(Object? valor) {
    const prohibidos = {
      'password',
      'passwordhash',
      'contrasena',
      'contraseña',
      'connectionstring',
      'authorization',
      'bearer',
      'token',
      'accesstoken',
      'refreshtoken',
      'jwt',
      'jwtkey',
      'secret',
      'secrets',
      'clavejwt',
      'apikey',
    };
    if (valor is Map) {
      for (final entrada in valor.entries) {
        final clave = entrada.key.toString().toLowerCase().replaceAll(
          RegExp('[^a-záéíóúñ]'),
          '',
        );
        if (prohibidos.contains(clave)) {
          throw const FormatException('Payload no permitido.');
        }
        _validarSinSecretos(entrada.value);
      }
    } else if (valor is List) {
      for (final elemento in valor) {
        _validarSinSecretos(elemento);
      }
    } else if (valor is String &&
        (RegExp(r'\bbearer\s+', caseSensitive: false).hasMatch(valor) ||
            RegExp(
              r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
            ).hasMatch(valor) ||
            RegExp(
              r'(password|connectionstring|jwtkey)\s*[=:]',
              caseSensitive: false,
            ).hasMatch(valor))) {
      throw const FormatException('Payload no permitido.');
    }
  }
}
