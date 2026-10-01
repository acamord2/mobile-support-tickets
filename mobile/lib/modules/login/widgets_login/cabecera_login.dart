import 'package:flutter/material.dart';
import '../../../app/theme/colores_app.dart';
import '../../../widgets/apartada/indicador_desconexion.dart';

/// Compone la cabecera de login con el indicador global a la derecha.
/// Reutiliza solo un widget compartido para no depender de otro módulo.
class CabeceraLogin extends StatelessWidget implements PreferredSizeWidget {
  /// Crea una cabecera visual sin navegación ni reglas de conectividad.
  const CabeceraLogin({super.key});

  /// Reserva el alto de la cabecera para que Scaffold distribuya el contenido.
  @override
  Size get preferredSize => const Size.fromHeight(40);

  /// Coloca el estado global en la esquina superior derecha sin título duplicado.
  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: ColoresApp.background,
    automaticallyImplyLeading: false,
    toolbarHeight: preferredSize.height,
    actions: const [IndicadorDesconexion(), SizedBox(width: 16)],
  );
}
