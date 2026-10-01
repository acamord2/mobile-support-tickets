import 'respuesta_api.dart';

/// Define el canal de nuestra API sin depender del transporte HTTP concreto.
/// Los futuros servicios consumen este contrato para mantener URL, headers y
/// errores de comunicación fuera de su lógica; todos reciben RespuestaApi.
abstract interface class IConexionApi {
  /// Solicita una lectura por ruta y token opcional, devolviendo la respuesta común.
  /// Deja el transporte a la implementación para desacoplar al consumidor.
  Future<RespuestaApi> get(String route, {String? token});

  /// Envía un payload de creación por ruta con autenticación opcional.
  /// Mantiene el contrato JSON común sin obligar al consumidor a construir HTTP.
  Future<RespuestaApi> post(String route, {String? token, Object? payload});

  /// Envía una actualización completa con datos y token opcionales.
  /// Delega su transporte para que el servicio solo determine ruta y contenido.
  Future<RespuestaApi> put(String route, {String? token, Object? payload});

  /// Envía una actualización parcial mediante el canal inyectado.
  /// Conserva la misma respuesta para evitar contratos distintos por verbo.
  Future<RespuestaApi> patch(String route, {String? token, Object? payload});

  /// Solicita un borrado sin cuerpo y con token opcional.
  /// Oculta el transporte y conserva el manejo común de respuestas vacías.
  Future<RespuestaApi> delete(String route, {String? token});

  /// Libera los recursos del canal cuando deja de utilizarse.
  /// Permite al punto de composición cerrar el transporte sin conocer su tipo.
  void close();
}
