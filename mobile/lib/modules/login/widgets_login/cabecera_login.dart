import 'package:flutter/material.dart';
import '../../../app/theme/colores_app.dart';
import '../../../widgets/apartada/indicador_desconexion.dart';

class CabeceraLogin extends StatelessWidget implements PreferredSizeWidget {
  const CabeceraLogin({super.key});

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
