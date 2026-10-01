/// Centraliza los textos utilizados por la plantilla y su infraestructura HTTP.
/// Permite reutilizar mensajes sin duplicarlos ni anticipar textos de pantallas
/// futuras; los errores técnicos no se muestran mediante excepciones sin procesar.
abstract class TextosApp {
  static const appName = 'Incidencias técnicas';
  static const requestTimeout = 'La petición excedió el tiempo de espera.';
  static const apiUnavailable = 'No se pudo conectar con la API.';
  static const invalidResponse =
      'La API devolvió una respuesta que no es JSON válido.';
  static const communicationError = 'Ocurrió un error al realizar la petición.';
  static const requestFailed = 'La API rechazó la petición.';
}
