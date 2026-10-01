import 'package:get/get.dart';
import '../models/sesion_usuario.dart';
import '../models/usuario.dart';

/// Conserva la sesión actual únicamente en memoria durante la ejecución.
/// Centraliza usuario y JWT para evitar copias en vistas; al reiniciar la app
/// desaparece y no utiliza almacenamiento permanente ni mecanismos offline.
class ServicioSesion extends GetxService {
  SesionUsuario? _sesion;

  /// Expone la identidad pública actual sin facilitar el JWT a la presentación.
  /// Permite mostrar el nombre del técnico o detectar que no existe sesión.
  Usuario? get usuario => _sesion?.usuario;

  /// Proporciona el token solo a consumidores que necesiten endpoints protegidos.
  /// Su valor no se imprime, muestra ni guarda fuera de esta instancia en memoria.
  String? get token => _sesion?.token;

  /// Consulta si se recibió una sesión validada antes de mostrar contenido autenticado.
  /// Usa el modelo actual sin duplicar otro estado que pudiera quedar desincronizado.
  bool get existeSesion => _sesion != null;

  /// Establece el resultado válido recibido por el servicio de autenticación.
  /// Guarda identidad y token juntos para no dejar una sesión parcialmente actualizada.
  void establecer(SesionUsuario sesion) => _sesion = sesion;

  /// Retira identidad y token del servicio sin persistencia ni endpoint logout.
  /// Permite cerrar sesión localmente porque la API utiliza JWT stateless.
  void limpiar() => _sesion = null;
}
