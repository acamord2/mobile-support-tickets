import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';

/// Muestra seguimiento local con fecha y foto opcional sin crear una galería.
/// Decodifica solo en detalle y representa imágenes dañadas con un mensaje público.
class SeguimientoTicket extends StatelessWidget {
  final List<Map<String, Object?>> registros;
  const SeguimientoTicket({super.key, required this.registros});

  Widget _foto(String contenido) {
    try {
      return Image.memory(
        base64Decode(contenido),
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text(TextosApp.imagenNoDisponible),
      );
    } catch (_) {
      return const Text(TextosApp.imagenNoDisponible);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(TextosApp.seguimiento, style: FuentesApp.tituloTarjeta),
      if (registros.isEmpty)
        const Text(TextosApp.sinSeguimiento, style: FuentesApp.body),
      for (final e in registros) ...[
        const SizedBox(height: 16),
        Text(
          DateTime.parse(
            e['created_at'] as String,
          ).toLocal().toString().split('.').first,
          style: FuentesApp.estadoModulo,
        ),
        Text(e['descripcion'] as String, style: FuentesApp.body),
        if (e['photo_base64'] is String) _foto(e['photo_base64'] as String),
        if (e['sync_status'] == 'pending')
          const Text(TextosApp.pendienteLocal, style: FuentesApp.estadoModulo),
        const Divider(),
      ],
    ],
  );
}
