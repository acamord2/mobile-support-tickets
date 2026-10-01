/// Centraliza códigos HTTP relevantes y su clasificación básica.
/// Los consumidores pueden expresar decisiones con nombres y el cliente comparte
/// el criterio de éxito sin repartir números mágicos por controllers o vistas.
abstract class ApiStatus {
  static const ok = 200;
  static const created = 201;
  static const noContent = 204;
  static const badRequest = 400;
  static const unauthorized = 401;
  static const forbidden = 403;
  static const notFound = 404;
  static const conflict = 409;
  static const internalServerError = 500;
  static const serviceUnavailable = 503;
  static const _redirectStart = 300;

  /// Clasifica como éxito cualquier respuesta 2xx, incluida una sin contenido.
  /// Usa el rango HTTP, en vez de exigir 200, para admitir respuestas válidas de
  /// creación o borrado sin acoplar el cliente a una operación de negocio.
  static bool isSuccess(int statusCode) =>
      statusCode >= ok && statusCode < _redirectStart;
}
