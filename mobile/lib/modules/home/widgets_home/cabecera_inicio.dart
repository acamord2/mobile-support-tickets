import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';
import '../../../widgets/apartada/indicador_desconexion.dart';

/// Separa acciones superiores de bienvenida e identidad en una única columna.
/// Recibe callbacks existentes; no cambia sincronización ni cierre de sesión.
class CabeceraInicio extends StatelessWidget {
  final String nombreTecnico;
  final String saludo;
  final bool sincronizando;
  final VoidCallback alSincronizar;
  final VoidCallback alCerrarSesion;
  const CabeceraInicio({
    super.key,
    required this.nombreTecnico,
    required this.saludo,
    required this.sincronizando,
    required this.alSincronizar,
    required this.alCerrarSesion,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              TextosApp.soporteTecnico,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: TextosApp.sincronizar,
            onPressed: sincronizando ? null : alSincronizar,
            icon: sincronizando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => alCerrarSesion(),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Text(TextosApp.cerrarSesion),
              ),
            ],
          ),
        ],
      ),
      const Divider(),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(saludo, style: FuentesApp.body),
                const SizedBox(height: 4),
                Text(nombreTecnico, style: FuentesApp.title),
              ],
            ),
          ),
          const IndicadorDesconexion(),
        ],
      ),
      const SizedBox(height: 20),
    ],
  );
}
