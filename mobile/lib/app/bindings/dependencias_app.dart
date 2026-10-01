import 'package:get/get.dart';
import '../network/cliente_api.dart';
import '../network/i_conexion_api.dart';
import '../network/conexion.dart';
import '../../controllers/controlador_login.dart';
import '../../controllers/controlador_inicio.dart';
import '../../services/servicio_autenticacion.dart';
import '../../services/servicio_sesion.dart';

/// Centraliza la selección e inyección del canal API mediante GetX.
/// Registra una fábrica diferida para no abrir transportes antes de necesitarlos
/// y permitir que futuros servicios soliciten IConexionApi por su contrato.
class DependenciasApp extends Bindings {
  /// Registra IConexionApi como Conexion con un cliente propio.
  /// GetX conserva la fábrica para reconstruirla si se libera; el callback de
  /// ciclo de vida onClose dispone el cliente al eliminar la dependencia.
  /// Conserva una sesión global en memoria y recrea servicios/controllers por ruta
  /// para liberar campos al navegar y obtener un formulario vacío al cerrar sesión.
  @override
  void dependencies() {
    Get.lazyPut<IConexionApi>(() => Conexion(ClienteApi()), fenix: true);
    Get.put(ServicioSesion(), permanent: true);
    Get.lazyPut(
      () => ServicioAutenticacion(Get.find<IConexionApi>()),
      fenix: true,
    );
    Get.lazyPut(
      () => ControladorLogin(
        Get.find<ServicioAutenticacion>(),
        Get.find<ServicioSesion>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ControladorInicio(Get.find<ServicioSesion>()),
      fenix: true,
    );
  }
}
