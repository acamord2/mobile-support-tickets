import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';
import '../../../widgets/apartada/indicador_desconexion.dart';

/// Muestra aplicación, saludo e identidad pública recibida del controller.
/// Reutiliza el indicador global a la derecha sin detectar red ni leer sesión.
class CabeceraInicio extends StatelessWidget {
  final String nombreTecnico;

  /// Recibe solo texto visible para separar presentación y autenticación.
  const CabeceraInicio({super.key, required this.nombreTecnico});

  /// Compone textos flexibles y el indicador sin imponer alturas al nombre.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(TextosApp.agenda, style: FuentesApp.title)),
          SizedBox(width: 16),
          IndicadorDesconexion(),
        ],
      ),
      const SizedBox(height: 24),
      const Text(TextosApp.bienvenida, style: FuentesApp.body),
      const SizedBox(height: 4),
      Text(nombreTecnico, style: FuentesApp.title),
    ],
  );
}
