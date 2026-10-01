import 'package:get/get.dart';
import '../../modules/login/main_login.dart';
import '../../modules/home/main_home.dart';
import 'rutas.dart';
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
  ];
}
