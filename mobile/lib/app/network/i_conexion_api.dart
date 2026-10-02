import 'respuesta_api.dart';

/// Define el canal de nuestra API sin depender del transporte HTTP concreto.
abstract interface class IConexionApi {
  /// Solicita una lectura por ruta y token opcional, devolviendo la respuesta común.
  Future<RespuestaApi> get(String route, {String? token});

  /// Envía un payload de creación por ruta con autenticación opcional.
  Future<RespuestaApi> post(String route, {String? token, Object? payload});

  /// Envía una actualización completa con datos y token opcionales.
  Future<RespuestaApi> put(String route, {String? token, Object? payload});

  /// Envía una actualización parcial mediante el canal inyectado.
  Future<RespuestaApi> patch(String route, {String? token, Object? payload});

  /// Solicita un borrado sin cuerpo y con token opcional.
  Future<RespuestaApi> delete(String route, {String? token});

  /// Libera los recursos del canal cuando deja de utilizarse.
  void close();
}
