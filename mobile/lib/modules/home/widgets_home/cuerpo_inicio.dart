import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import 'tarjeta_modulo.dart';

class CuerpoInicio extends StatelessWidget {
  final VoidCallback? alAbrirTickets;
  final VoidCallback? alSincronizar;

  /// Permite habilitarlos después sin rediseñar la composición principal.
  const CuerpoInicio({super.key, this.alAbrirTickets, this.alSincronizar});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TarjetaModulo(
        icono: Icons.assignment_outlined,
        titulo: TextosApp.misTickets,
        descripcion: TextosApp.descripcionTickets,
        accion: alAbrirTickets,
        habilitado: alAbrirTickets != null,
      ),
      const SizedBox(height: 16),
      TarjetaModulo(
        icono: Icons.sync,
        titulo: TextosApp.sincronizar,
        descripcion: TextosApp.descripcionSincronizar,
        accion: alSincronizar,
        habilitado: alSincronizar != null,
      ),
    ],
  );
}
