import 'package:flutter/material.dart';

/// Centraliza los colores utilizados por Login, Home, tarjetas y mensajes de error.
/// Comparte constantes de Color para mantener una presentación consistente
/// sin repetir valores en las vistas ni agregar un sistema de diseño complejo.
abstract class ColoresApp {
  static const background = Color(0xFFFAFAFA);
  static const text = Color(0xFF212121);
  static const primary = Color(0xFF195A9B);
  static const seleccion = primary;
  static const error = Color(0xFFB3261E);
  static const tarjeta = Color(0xFFFFFFFF);
  static const borde = Color(0xFFD6DCE3);
  static const deshabilitado = Color(0xFF626B76);
}
