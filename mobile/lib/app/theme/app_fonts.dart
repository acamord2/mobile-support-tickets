import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centraliza la tipografía que realmente utiliza la plantilla.
/// Emplea la fuente predeterminada de Flutter, con tamaño y peso compartidos,
/// para reutilizar el estilo sin agregar una dependencia o fuente externa.
abstract class AppFonts {
  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.text,
  );
}
