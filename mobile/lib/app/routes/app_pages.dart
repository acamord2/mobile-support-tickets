import 'package:get/get.dart';
import '../../views/initial_view.dart';
import 'app_routes.dart';

/// Relaciona los nombres centralizados con las vistas mediante [GetPage].
/// Se mantiene fuera de main.dart para incorporar páginas futuras sin mezclar
/// navegación y arranque. Solo registra la pantalla de plantilla existente.
abstract class AppPages {
  static const initial = Routes.initial;

  static final pages = <GetPage>[
    GetPage(name: Routes.initial, page: () => const InitialView()),
  ];
}
