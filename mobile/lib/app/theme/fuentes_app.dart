import 'package:flutter/material.dart';
import 'colores_app.dart';

/// Centraliza la tipografía utilizada por Login, Home, tarjetas y mensajes de error.
/// Emplea la fuente predeterminada de Flutter, con tamaño y peso compartidos,
/// para reutilizar el estilo sin agregar una dependencia o fuente externa.
abstract class FuentesApp {
  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: ColoresApp.text,
  );
  static const error = TextStyle(fontSize: 14, color: ColoresApp.error);
  static const tituloTarjeta = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: ColoresApp.text,
  );
  static const estadoModulo = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: ColoresApp.deshabilitado,
  );
  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: ColoresApp.text,
  );
}
