import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/services/servicio_conectividad.dart';
import '../../app/theme/colores_app.dart';

/// Muestra desconexión confirmada; no realiza consultas de red.
class IndicadorDesconexion extends GetView<ServicioConectividad> {
  const IndicadorDesconexion({super.key});

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
