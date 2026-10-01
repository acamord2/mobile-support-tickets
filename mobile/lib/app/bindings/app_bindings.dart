import 'package:get/get.dart';
import '../network/api_client.dart';
import '../network/api_connection.dart';
import '../network/conexion.dart';

/// Centraliza la selección e inyección del canal API mediante GetX.
/// Registra una fábrica diferida para no abrir transportes antes de necesitarlos
/// y permitir que futuros servicios soliciten ApiConnection por su contrato.
class AppBindings extends Bindings {
  /// Registra ApiConnection como Conexion con un cliente propio.
  /// GetX conserva la fábrica para reconstruirla si se libera; el callback de
  /// ciclo de vida onClose dispone el cliente al eliminar la dependencia.
  @override
  void dependencies() {
    Get.lazyPut<ApiConnection>(() => Conexion(ApiClient()), fenix: true);
  }
}
