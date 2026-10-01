import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/constants/textos_app.dart';

/// Muestra los bytes Base64 procesados que se guardan/envían, sin otra copia de foto.
/// Reutilizable en borrador y bitácora; datos inválidos tienen mensaje público.
class FotoProcesada extends StatelessWidget {
  final String base64;
  const FotoProcesada({super.key, required this.base64});
  @override
  Widget build(BuildContext context) {
    try {
      return Image.memory(
        base64Decode(base64),
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text(TextosApp.imagenNoDisponible),
      );
    } catch (_) {
      return const Text(TextosApp.imagenNoDisponible);
    }
  }
}
