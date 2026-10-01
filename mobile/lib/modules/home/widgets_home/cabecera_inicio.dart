import 'package:flutter/material.dart';
import '../../../app/theme/colores_app.dart';
import '../../../widgets/apartada/indicador_desconexion.dart';

/// Presenta la cabecera de Home y el indicador transversal de desconexión.
/// Conserva la composición dentro del módulo sin importar widgets de login.
class CabeceraInicio extends StatelessWidget implements PreferredSizeWidget {
  /// Crea una cabecera sencilla que solo consume estado visual compartido.
  const CabeceraInicio({super.key});

  /// Reserva el espacio superior para distribuir correctamente la pantalla.
  @override
  Size get preferredSize => const Size.fromHeight(40);

  /// Alinea el indicador a la derecha sin añadir navegación o lógica de negocio.
  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: ColoresApp.background,
    automaticallyImplyLeading: false,
    toolbarHeight: preferredSize.height,
    actions: const [IndicadorDesconexion(), SizedBox(width: 16)],
  );
}
