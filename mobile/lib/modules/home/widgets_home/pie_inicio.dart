import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';

/// Presenta logout y lo delega al controller mediante un callback existente.
/// No duplica limpieza de sesión ni navegación y sigue disponible offline.
class PieInicio extends StatelessWidget {
  final VoidCallback alCerrarSesion;

  /// Recibe la acción existente para mantener el pie independiente de sesión.
  const PieInicio({super.key, required this.alCerrarSesion});

  /// Ofrece un botón con área táctil mínima de 48 puntos y ancho disponible.
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
    onPressed: alCerrarSesion,
    icon: const Icon(Icons.logout),
    label: const Text(TextosApp.cerrarSesion),
  );
}
