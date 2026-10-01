import 'package:get/get.dart';
import '../../modules/login/main_login.dart';
import '../../modules/home/main_home.dart';
import 'rutas.dart';

/// Relaciona los nombres centralizados con las vistas mediante [GetPage].
/// Se mantiene fuera de main.dart para incorporar páginas futuras sin mezclar
/// navegación y arranque. Registra login y la pantalla neutra autenticada.
abstract class PaginasApp {
  static const initial = Rutas.login;

  static final pages = <GetPage>[
    GetPage(name: Rutas.login, page: () => const VistaLogin()),
    GetPage(name: Rutas.inicio, page: () => const VistaInicio()),
  ];
}
