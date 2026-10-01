import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/paginas_app.dart';
import 'app/constants/textos_app.dart';
import 'app/bindings/dependencias_app.dart';

/// Inicia la plantilla mediante [AppTickets].
/// La configuración de navegación permanece en su módulo para que las futuras
/// pantallas se incorporen sin ampliar la responsabilidad del punto de entrada.
void main() {
  runApp(const AppTickets());
}

/// Configura GetX usando las rutas centralizadas de la aplicación.
/// Mantiene la inicialización independiente de las vistas para facilitar cambios
/// de navegación sin introducir lógica de negocio en el arranque.
class AppTickets extends StatelessWidget {
  /// Crea la configuración raíz sin estado propio.
  /// Delega la navegación a GetX porque esta plantilla solo configura la app.
  const AppTickets({super.key});

  /// Construye [GetMaterialApp] con la ruta inicial y las páginas de [PaginasApp].
  /// Usa ese registro único y el binding central para evitar rutas y selección
  /// de transportes repartidas entre vistas, sin añadir funcionalidades o UI.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: TextosApp.appName,
      initialBinding: DependenciasApp(),
      initialRoute: PaginasApp.initial,
      getPages: PaginasApp.pages,
    );
  }
}
