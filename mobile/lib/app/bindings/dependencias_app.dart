import '../database/repositorio_tickets.dart';
import '../database/repositorio_sucursales.dart';
import '../database/repositorio_evidencias.dart';
import '../services/servicio_imagen.dart';
import '../../modules/nuevo_ticket/servicio_nuevo_ticket.dart';
import '../../modules/nuevo_ticket/controlador_nuevo_ticket.dart';
import 'package:get/get.dart';
import '../network/cliente_api.dart';
import '../network/i_conexion_api.dart';
import '../network/conexion.dart';
import '../../modules/login/controlador_login.dart';
import '../../modules/home/controlador_inicio.dart';
import '../../modules/login/servicio_autenticacion.dart';
import '../services/servicio_sesion.dart';
import '../services/servicio_conectividad.dart';
import '../database/conexion_sqlite.dart';
import '../database/operaciones_sqlite.dart';
import '../database/repositorio_cola.dart';
import '../services/servicio_sincronizacion.dart';
import '../services/almacenamiento_token.dart';
import '../database/repositorio_sesion_local.dart';
import '../../modules/arranque/controlador_arranque.dart';

/// Conserva el transporte global mientras la aplicación está abierta para que retirar Login no cierre el cliente que todavía utiliza sincronización.
class DependenciasApp extends Bindings {
  /// Registra IConexionApi como Conexion permanente con un cliente propio.
  @override
  void dependencies() {
    if (!Get.isRegistered<IConexionApi>()) {
      Get.put<IConexionApi>(Conexion(ClienteApi()), permanent: true);
    }
    Get.put(ServicioConectividad(), permanent: true);
    Get.lazyPut(() => ConexionSqlite(), fenix: true);
    Get.lazyPut(
      () => OperacionesSqlite(Get.find<ConexionSqlite>()),
      fenix: true,
    );
    Get.lazyPut(
      () => RepositorioCola(Get.find<OperacionesSqlite>()),
      fenix: true,
    );
    Get.lazyPut(
      () => RepositorioTickets(Get.find<OperacionesSqlite>()),
      fenix: true,
    );
    Get.lazyPut(
      () => RepositorioSucursales(Get.find<OperacionesSqlite>()),
      fenix: true,
    );
    Get.lazyPut(
      () => RepositorioEvidencias(Get.find<OperacionesSqlite>()),
      fenix: true,
    );
    Get.lazyPut(() => ServicioImagen(), fenix: true);
    Get.lazyPut(
      () => ServicioNuevoTicket(
        Get.find<RepositorioTickets>(),
        Get.find<RepositorioEvidencias>(),
        Get.find<ServicioImagen>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ControladorNuevoTicket(
        Get.find<ServicioNuevoTicket>(),
        Get.find<RepositorioSucursales>(),
        Get.find<ServicioSesion>(),
      ),
      fenix: true,
    );
    Get.lazyPut<AlmacenamientoToken>(
      () => AlmacenamientoTokenSeguro(),
      fenix: true,
    );
    Get.lazyPut(
      () => RepositorioSesionLocal(
        Get.find<OperacionesSqlite>(),
        Get.find<AlmacenamientoToken>(),
      ),
      fenix: true,
    );
    if (!Get.isRegistered<ServicioSesion>()) {
      Get.put(
        ServicioSesion(Get.find<RepositorioSesionLocal>()),
        permanent: true,
      );
    }
    Get.lazyPut(
      () => ControladorArranque(Get.find<ServicioSesion>()),
      fenix: true,
    );
    Get.lazyPut(
      () => ServicioSincronizacion(
        Get.find<ServicioConectividad>(),
        Get.find<IConexionApi>(),
        Get.find<RepositorioCola>(),
        Get.find<ServicioSesion>(),
        tickets: Get.find<RepositorioTickets>(),
        sucursales: Get.find<RepositorioSucursales>(),
        evidencias: Get.find<RepositorioEvidencias>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ServicioAutenticacion(
        Get.find<IConexionApi>(),
        conectividad: Get.find<ServicioConectividad>(),
      ),
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
      () => ControladorInicio(
        Get.find<ServicioSesion>(),
        repositorio: Get.find<RepositorioTickets>(),
        sucursales: Get.find<RepositorioSucursales>(),
        sincronizacion: Get.find<ServicioSincronizacion>(),
        conectividad: Get.find<ServicioConectividad>(),
      ),
      fenix: true,
    );
  }
}
