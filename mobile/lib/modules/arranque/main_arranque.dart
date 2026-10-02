import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import 'controlador_arranque.dart';

/// Espera la restauración local antes de mostrar Login o Home.
class VistaArranque extends GetView<ControladorArranque> {
  const VistaArranque({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Obx(
        () => controller.error.value.isEmpty
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(TextosApp.cargandoSesion),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(TextosApp.errorSesion),
                  TextButton(
                    onPressed: controller.restaurar,
                    child: const Text(TextosApp.reintentar),
                  ),
                ],
              ),
      ),
    ),
  );
}
