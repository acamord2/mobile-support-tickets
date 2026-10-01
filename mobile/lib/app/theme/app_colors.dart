import 'package:flutter/material.dart';

/// Centraliza los únicos colores utilizados por la vista inicial.
/// Mantiene la plantilla sencilla y evita valores de Color repetidos al reutilizar
/// su fondo y texto, sin definir una paleta de pantallas todavía inexistentes.
abstract class AppColors {
  static const background = Color(0xFFFAFAFA);
  static const text = Color(0xFF212121);
}
