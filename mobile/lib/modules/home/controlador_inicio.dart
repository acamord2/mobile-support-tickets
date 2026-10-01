import 'package:get/get.dart';
import '../../app/routes/rutas.dart';
import '../../models/usuario.dart';
import '../../app/services/servicio_sesion.dart';
import '../../app/constants/textos_app.dart';

/// Coordina la identidad y salida del Home principal autenticado.
/// Delega sesión persistente al servicio y mantiene navegación fuera de la vista;
/// no consume endpoints ni anticipa funciones de tickets.
class ControladorInicio extends GetxController {
  final ServicioSesion _sesion;
  bool _cerrando = false;

  /// Recibe la sesión compartida para mostrar identidad y limpiar acceso local.
  /// No crea otra sesión ni expone el token a la vista.
  ControladorInicio(this._sesion);

  /// Devuelve únicamente la identidad pública que puede mostrar la pantalla.
  /// El JWT queda en ServicioSesion y no llega a la presentación.
  Usuario? get usuario => _sesion.usuario;

  /// Expone el nombre público autenticado sin consultar datos remotos o locales.
  /// La vista recibe texto listo para representar y nunca necesita leer el JWT.
  String get nombreTecnico => usuario?.name ?? '';

  /// Devuelve al login si se abrió la ruta autenticada sin una identidad local.
  /// Comprueba tras montar la vista para no navegar durante su construcción.
  @override
  void onReady() {
    super.onReady();
    if (!_sesion.existeSesion) Get.offAllNamed<void>(Rutas.login);
  }

  /// Limpia identidad/token persistidos y reemplaza el historial por Login.
  /// Comprueba pendientes mediante el servicio, preserva la cola y permite reintento.
  Future<void> cerrarSesion() async {
    if (_cerrando) return;
    _cerrando = true;
    try {
      if (await _sesion.limpiar()) {
        if (!isClosed) Get.offAllNamed<void>(Rutas.login);
      } else if (!isClosed) {
        Get.snackbar(TextosApp.cerrarSesion, TextosApp.errorSesion);
      }
    } finally {
      _cerrando = false;
    }
  }
}
