import 'sesion_usuario.dart';

/// Devuelve una sesión válida o un mensaje controlado desde el servicio.
/// Evita que el controlador interprete JSON o códigos de transporte y mantiene
/// el resultado limitado a lo necesario para autenticar y presentar errores.
class ResultadoAutenticacion {
  final SesionUsuario? sesion;
  final String? mensaje;

  /// Construye el resultado que el servicio determina después de comprobar la API.
  /// Permite representar errores sin lanzar excepciones ni conservar payloads privados.
  const ResultadoAutenticacion({this.sesion, this.mensaje});

  /// Indica éxito por la presencia de una sesión ya validada por el servicio.
  /// Evita duplicar un booleano que pudiera contradecir al modelo recibido.
  bool get exito => sesion != null;
}
