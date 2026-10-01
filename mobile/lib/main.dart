import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/paginas_app.dart';
import 'app/constants/textos_app.dart';
import 'app/bindings/dependencias_app.dart';
import 'app/theme/colores_app.dart';

/// Inicia la aplicación mediante [AppTickets].
/// La configuración de navegación permanece en su módulo para que las futuras
/// pantallas se incorporen sin ampliar la responsabilidad del punto de entrada.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppTickets());
}

/// Configura GetX usando las rutas centralizadas de la aplicación.
/// Mantiene la inicialización independiente de las vistas para facilitar cambios
/// de navegación sin introducir lógica de negocio en el arranque.
class AppTickets extends StatelessWidget {
  /// Crea la configuración raíz sin estado propio.
  /// Delega la navegación a GetX para separar el arranque de la autenticación.
  const AppTickets({super.key});

  /// Construye [GetMaterialApp] con la ruta inicial y las páginas de [PaginasApp].
  /// Usa ese registro único y el binding central para evitar rutas y selección
  /// de transportes repartidas entre vistas y mantiene el tema centralizado.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: TextosApp.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: ColoresApp.primary),
      ),
      initialBinding: DependenciasApp(),
      initialRoute: PaginasApp.initial,
      getPages: PaginasApp.pages,
    );
  }
}
