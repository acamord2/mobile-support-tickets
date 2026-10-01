import 'package:get/get.dart';
import '../../modules/detalle_ticket/main_detalle_ticket.dart';
import '../../modules/detalle_ticket/controlador_detalle_ticket.dart';
import '../database/repositorio_tickets.dart';
import '../database/repositorio_sucursales.dart';
import '../services/servicio_sesion.dart';
import '../../modules/login/main_login.dart';
import '../../modules/home/main_home.dart';
import 'rutas.dart';
import '../../modules/nuevo_ticket/main_nuevo_ticket.dart';
import '../../modules/arranque/main_arranque.dart';

/// Relaciona los nombres centralizados con las vistas mediante [GetPage].
/// Se mantiene fuera de main.dart para incorporar páginas futuras sin mezclar
/// navegación y arranque. Registra carga, Login y Home según la sesión local.
abstract class PaginasApp {
  static const initial = Rutas.arranque;

  static final pages = <GetPage>[
    GetPage(name: Rutas.arranque, page: () => const VistaArranque()),
    GetPage(name: Rutas.login, page: () => const VistaLogin()),
    GetPage(name: Rutas.inicio, page: () => const VistaInicio()),
    GetPage(name: Rutas.nuevoTicket, page: () => const VistaNuevoTicket()),
    GetPage(
      name: Rutas.detalleTicket,
      page: () => const VistaDetalleTicket(),
      binding: BindingsBuilder(
        () => Get.lazyPut(
          () => ControladorDetalleTicket(
            Get.find<RepositorioTickets>(),
            Get.find<RepositorioSucursales>(),
            Get.find<ServicioSesion>(),
          ),
        ),
      ),
    ),
  ];
}
