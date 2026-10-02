import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/routes/rutas.dart';
import '../../app/services/servicio_sesion.dart';

/// Restaura sesión antes de decidir Home o Login sin consultar la API.
class ControladorArranque extends GetxController {
  final ServicioSesion _sesion;
  final error = ''.obs;
  bool _cargando = false;

  ControladorArranque(this._sesion);

  /// Inicia restauración después de montar la pantalla mínima de carga.
  @override
  void onReady() {
    super.onReady();
    restaurar();
  }

  /// Coordina restauración única por intento y navega solo cuando concluye.
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
