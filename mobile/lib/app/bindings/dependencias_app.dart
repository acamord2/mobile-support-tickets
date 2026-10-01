import 'package:get/get.dart';
import '../network/cliente_api.dart';
import '../network/i_conexion_api.dart';
import '../network/conexion.dart';

/// Centraliza la selección e inyección del canal API mediante GetX.
/// Registra una fábrica diferida para no abrir transportes antes de necesitarlos
/// y permitir que futuros servicios soliciten IConexionApi por su contrato.
class DependenciasApp extends Bindings {
  /// Registra IConexionApi como Conexion con un cliente propio.
  /// GetX conserva la fábrica para reconstruirla si se libera; el callback de
  /// ciclo de vida onClose dispone el cliente al eliminar la dependencia.
  @override
  void dependencies() {
    Get.lazyPut<IConexionApi>(() => Conexion(ClienteApi()), fenix: true);
  }
}
