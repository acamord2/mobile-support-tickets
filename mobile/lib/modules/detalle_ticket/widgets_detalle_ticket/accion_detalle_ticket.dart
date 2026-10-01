import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/colores_app.dart';
import '../../../app/theme/fuentes_app.dart';

/// Representa atención disponible o estado de consulta sin decidir transiciones.
/// Mantiene la acción grande y bloqueada durante persistencia local.
class AccionDetalleTicket extends StatelessWidget {
  final bool puedeComenzar, guardando;
  final String estado;
  final VoidCallback alComenzar;
  const AccionDetalleTicket({
    super.key,
    required this.puedeComenzar,
    required this.guardando,
    required this.estado,
    required this.alComenzar,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      const SizedBox(height: 16),
      if (puedeComenzar)
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ColoresApp.primary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
          onPressed: guardando ? null : alComenzar,
          child: guardando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(TextosApp.comenzarAtencion),
        )
      else
        Text(estado, style: FuentesApp.body),
    ],
  );
}
