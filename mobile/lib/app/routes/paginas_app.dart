import '../../modules/solicitudes/main_solicitar_estado.dart';
import '../../modules/solicitudes/controlador_solicitar_estado.dart';
import '../../modules/home/main_tickets_tecnico.dart';
import '../database/repositorio_solicitudes.dart';
import 'package:get/get.dart';
import '../../modules/detalle_ticket/main_detalle_ticket.dart';
import '../../modules/detalle_ticket/controlador_detalle_ticket.dart';
import '../database/repositorio_tickets.dart';
import '../database/repositorio_sucursales.dart';
import '../services/servicio_sesion.dart';
import '../services/servicio_imagen.dart';
import '../database/repositorio_evidencias.dart';
import '../../modules/editar_ticket/main_editar_ticket.dart';
import '../../modules/editar_ticket/controlador_editar_ticket.dart';
import '../../modules/seguimiento/main_seguimiento.dart';
import '../../modules/seguimiento/controlador_seguimiento.dart';
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
    GetPage(
      name: Rutas.ticketsTecnico,
      page: () => const VistaTicketsTecnico(),
    ),
    GetPage(
      name: Rutas.solicitarEstado,
      page: () => const VistaSolicitarEstado(),
      binding: BindingsBuilder(
        () => Get.lazyPut(
          () => ControladorSolicitarEstado(
            RepositorioSolicitudes(Get.find<RepositorioTickets>().sql),
            Get.find<ServicioSesion>(),
          ),
        ),
      ),
    ),
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
            Get.find<RepositorioEvidencias>(),
          ),
        ),
      ),
    ),
    GetPage(
      name: Rutas.editarTicket,
      page: () => const VistaEditarTicket(),
      binding: BindingsBuilder(
        () => Get.lazyPut(
          () => ControladorEditarTicket(
            Get.find<RepositorioTickets>(),
            Get.find<ServicioSesion>(),
          ),
        ),
      ),
    ),
    GetPage(
      name: Rutas.seguimiento,
      page: () => const VistaSeguimiento(),
      binding: BindingsBuilder(
        () => Get.lazyPut(
          () => ControladorSeguimiento(
            Get.find<RepositorioTickets>(),
            Get.find<RepositorioEvidencias>(),
            Get.find<ServicioSesion>(),
            Get.find<ServicioImagen>(),
          ),
        ),
      ),
    ),
  ];
}
