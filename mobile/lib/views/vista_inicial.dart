import 'package:flutter/material.dart';
import '../app/constants/textos_app.dart';
import '../app/theme/colores_app.dart';
import '../app/theme/fuentes_app.dart';

/// Presenta la pantalla neutra con la que se verifica la plantilla.
/// No recibe datos ni controllers porque las funcionalidades se crearán después.
class VistaInicial extends StatelessWidget {
  /// Crea una vista sin estado ni dependencias de negocio.
  /// Permite que GetX construya la pantalla al resolver la ruta inicial.
  const VistaInicial({super.key});

  /// Construye un Scaffold con el título centrado.
  /// Mantiene visible el arranque para comprobar que la ruta inicial se resolvió
  /// sin introducir todavía formularios, navegación adicional o llamadas API.
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ColoresApp.background,
      body: Center(child: Text(TextosApp.appName, style: FuentesApp.body)),
    );
  }
}
