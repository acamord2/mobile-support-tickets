/// Conserva JSON decodificado y el código real cuando hubo respuesta HTTP; un código null distingue fallos de comunicación de respuestas de error emitidas por la API.
class RespuestaApi {
  final int? statusCode;
  final Object? data;
  final String? message;
  final bool success;

  const RespuestaApi({
    this.statusCode,
    this.data,
    this.message,
    required this.success,
  });
}
