import 'package:get/get.dart';
import '../app/routes/rutas.dart';
import '../models/usuario.dart';
import '../services/servicio_sesion.dart';

/// Coordina la identidad y salida de la pantalla neutra autenticada.
/// Delega la memoria al servicio y mantiene navegación fuera de la vista;
/// no consume endpoints ni anticipa funciones de tickets.
class ControladorInicio extends GetxController {
  final ServicioSesion _sesion;

  /// Recibe la sesión compartida para mostrar identidad y limpiar acceso local.
  /// No crea otra sesión ni expone el token a la vista.
  ControladorInicio(this._sesion);

  /// Devuelve únicamente la identidad pública que puede mostrar la pantalla.
  /// El JWT queda en ServicioSesion y no llega a la presentación.
  Usuario? get usuario => _sesion.usuario;

  /// Devuelve al login si se abrió la ruta autenticada sin una sesión en memoria.
  /// Comprueba tras montar la vista para no navegar durante su construcción.
  @override
  void onReady() {
    super.onReady();
    if (!_sesion.existeSesion) Get.offAllNamed<void>(Rutas.login);
  }

  /// Limpia la sesión y reemplaza todo el historial por el login.
  /// Evita regresar con atrás a la pantalla autenticada y no inventa un logout HTTP.
  void cerrarSesion() {
    _sesion.limpiar();
    Get.offAllNamed<void>(Rutas.login);
  }
}
