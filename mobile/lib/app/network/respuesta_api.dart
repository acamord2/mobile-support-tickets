/// Representa el resultado común de una petición sin depender de modelos de negocio.
/// Conserva JSON decodificado y el código real cuando hubo respuesta HTTP; un código
/// null distingue fallos de comunicación de respuestas de error emitidas por la API.
class RespuestaApi {
  final int? statusCode;
  final Object? data;
  final String? message;
  final bool success;

  /// Construye un resultado inmutable con datos públicos de la comunicación.
  /// El cliente determina success y message para que los consumidores manejen
  /// errores de forma uniforme sin conocer http.Response o excepciones de transporte.
  const RespuestaApi({
    this.statusCode,
    this.data,
    this.message,
    required this.success,
  });
}
