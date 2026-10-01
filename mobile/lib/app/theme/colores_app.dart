import 'package:flutter/material.dart';

/// Centraliza los colores utilizados por login, bienvenida y mensajes de error.
/// Comparte constantes de Color para mantener una presentación consistente
/// sin repetir valores en las vistas ni agregar un sistema de diseño complejo.
abstract class ColoresApp {
  static const background = Color(0xFFFAFAFA);
  static const text = Color(0xFF212121);
  static const primary = Color(0xFF195A9B);
  static const error = Color(0xFFB3261E);
}
