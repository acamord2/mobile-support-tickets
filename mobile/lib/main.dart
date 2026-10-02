import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/paginas_app.dart';
import 'app/constants/textos_app.dart';
import 'app/bindings/dependencias_app.dart';
import 'app/theme/colores_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppTickets());
}

/// Configura rutas, dependencias y tema centralizados.
class AppTickets extends StatelessWidget {
  const AppTickets({super.key});

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
