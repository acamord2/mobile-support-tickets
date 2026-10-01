import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/routes/rutas.dart';
import '../../app/services/servicio_sesion.dart';

/// Restaura sesión antes de decidir Home o Login sin consultar la API.
/// Evita mostrar Login fugazmente y ofrece reintento ante fallos de almacenamiento.
class ControladorArranque extends GetxController {
  final ServicioSesion _sesion;
  final error = ''.obs;
  bool _cargando = false;

  /// Recibe la fachada compartida para mantener SQL y token fuera del controlador.
  ControladorArranque(this._sesion);

  /// Inicia restauración después de montar la pantalla mínima de carga.
  @override
  void onReady() {
    super.onReady();
    restaurar();
  }

  /// Coordina restauración única por intento y navega solo cuando concluye.
  /// No confunde un fallo local con ausencia de sesión ni borra datos para recuperarse.
  Future<void> restaurar() async {
    if (_cargando) return;
    _cargando = true;
    error.value = '';
    final exito = await _sesion.restaurar();
    _cargando = false;
    if (isClosed) return;
    if (!exito) {
      error.value = TextosApp.errorSesion;
      return;
    }
    Get.offAllNamed<void>(_sesion.existeSesion ? Rutas.inicio : Rutas.login);
  }
}
