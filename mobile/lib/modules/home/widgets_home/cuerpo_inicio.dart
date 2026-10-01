import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import 'tarjeta_modulo.dart';

/// Compone los accesos principales mediante una misma tarjeta reutilizable.
/// Recibe acciones futuras sin importar módulos inexistentes ni ejecutar procesos.
class CuerpoInicio extends StatelessWidget {
  final VoidCallback? alAbrirTickets;
  final VoidCallback? alSincronizar;

  /// Deja accesos deshabilitados mientras no se conecten acciones reales.
  /// Permite habilitarlos después sin rediseñar la composición principal.
  const CuerpoInicio({super.key, this.alAbrirTickets, this.alSincronizar});

  /// Muestra accesos informativos sin estadísticas ni datos de negocio ficticios.
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
