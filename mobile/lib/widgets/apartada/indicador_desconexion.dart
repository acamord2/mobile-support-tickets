import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/services/servicio_conectividad.dart';
import '../../app/theme/colores_app.dart';

/// Muestra un icono pequeño únicamente cuando el servicio confirma ausencia de red.
/// Consume estado observable compartido; no detecta red ni realiza consultas API.
class IndicadorDesconexion extends GetView<ServicioConectividad> {
  /// Crea el componente global reutilizable sin pertenecer a Login o Home.
  const IndicadorDesconexion({super.key});

  /// Reacciona visualmente al estado y ofrece un texto accesible centralizado.
  /// Con red o estado desconocido no ocupa espacio ni muestra información técnica.
  @override
  Widget build(BuildContext context) => Obx(
    () => controller.sinRed
        ? const Tooltip(
            message: TextosApp.sinConexion,
            child: Icon(
              Icons.cloud_off,
              size: 20,
              color: ColoresApp.error,
              semanticLabel: TextosApp.sinConexion,
            ),
          )
        : const SizedBox.shrink(),
  );
}
