import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';

/// Presenta conteos recibidos desde SQLite sin calcular consultas en la vista.
class ResumenAgenda extends StatelessWidget {
  final Map<String, int> conteos;
  const ResumenAgenda({super.key, required this.conteos});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 8,
    children: [
      Text(
        '${TextosApp.pendientes}: ${conteos['Pending'] ?? 0}',
        style: FuentesApp.body,
      ),
      Text(
        '${TextosApp.enAtencion}: ${conteos['InProgress'] ?? 0}',
        style: FuentesApp.body,
      ),
      Text(
        '${TextosApp.resueltos}: ${conteos['Resolved'] ?? 0}',
        style: FuentesApp.body,
      ),
    ],
  );
}
