import 'package:get/get.dart';
import '../../views/vista_inicial.dart';
import 'rutas.dart';

/// Relaciona los nombres centralizados con las vistas mediante [GetPage].
/// Se mantiene fuera de main.dart para incorporar páginas futuras sin mezclar
/// navegación y arranque. Solo registra la pantalla de plantilla existente.
abstract class PaginasApp {
  static const initial = Rutas.initial;

  static final pages = <GetPage>[
    GetPage(name: Rutas.initial, page: () => const VistaInicial()),
  ];
}
