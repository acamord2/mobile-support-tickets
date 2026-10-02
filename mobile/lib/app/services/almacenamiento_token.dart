import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Aísla las operaciones del JWT para probar sesión sin secretos reales.
abstract class AlmacenamientoToken {
  /// Recupera exclusivamente el JWT dentro del servicio para restaurar acceso remoto.
  Future<String?> leer();

  /// Guarda el JWT protegido sin serializarlo en SQLite ni imprimirlo.
  Future<void> guardar(String token);

  /// Retira el JWT al salir conservando datos locales.
  Future<void> eliminar();
}

/// Usa flutter_secure_storage para evitar JWT en SQLite normal.
class AlmacenamientoTokenSeguro implements AlmacenamientoToken {
  final FlutterSecureStorage _almacen;
  static const _clave = 'token_sesion';

  AlmacenamientoTokenSeguro({FlutterSecureStorage? almacen})
    : _almacen = almacen ?? const FlutterSecureStorage();

  /// Lee solo la clave propia sin enumerar otros secretos del sistema.
  @override
  Future<String?> leer() => _almacen.read(key: _clave);

  /// Escribe el JWT protegido antes de publicar identidad persistida.
  @override
  Future<void> guardar(String token) =>
      _almacen.write(key: _clave, value: token);

  /// Elimina únicamente la clave de sesión para preservar almacenamiento ajeno.
  @override
  Future<void> eliminar() => _almacen.delete(key: _clave);
}
