import 'package:flutter/material.dart';

/// Presenta expansión controlada externamente; no almacena estado individual que permita dos listas abiertas.
class CardSeccionCoordinador extends StatelessWidget {
  final String titulo, resumen;
  final bool abierta;
  final Widget contenido;
  final VoidCallback alAlternar;
  const CardSeccionCoordinador({
    super.key,
    required this.titulo,
    required this.resumen,
    required this.abierta,
    required this.contenido,
    required this.alAlternar,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        ListTile(
          title: Text(titulo),
          subtitle: Text(resumen),
          trailing: Icon(abierta ? Icons.expand_less : Icons.expand_more),
          onTap: alAlternar,
        ),
        if (abierta) ...[
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12), child: contenido),
        ],
      ],
    ),
  );
}
