import 'package:flutter/material.dart';
import '../app/constants/app_texts.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_fonts.dart';

/// Presenta la pantalla neutra con la que se verifica la plantilla.
/// No recibe datos ni controllers porque las funcionalidades se crearán después.
class InitialView extends StatelessWidget {
  /// Crea una vista sin estado ni dependencias de negocio.
  /// Permite que GetX construya la pantalla al resolver la ruta inicial.
  const InitialView({super.key});

  /// Construye un Scaffold con el título centrado.
  /// Mantiene visible el arranque para comprobar que la ruta inicial se resolvió
  /// sin introducir todavía formularios, navegación adicional o llamadas API.
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: Text(AppTexts.appName, style: AppFonts.body)),
    );
  }
}
