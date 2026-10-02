import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';

/// No duplica limpieza de sesión ni navegación y sigue disponible offline.
class PieInicio extends StatelessWidget {
  final VoidCallback alCerrarSesion;

  const PieInicio({super.key, required this.alCerrarSesion});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
    onPressed: alCerrarSesion,
    icon: const Icon(Icons.logout),
    label: const Text(TextosApp.cerrarSesion),
  );
}
