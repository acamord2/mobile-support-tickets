import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import 'controlador_arranque.dart';

/// Muestra carga mínima mientras se restaura sesión, sin anticipar Login o Home.
/// Delega almacenamiento al controlador y permite reintento con mensaje controlado.
class VistaArranque extends GetView<ControladorArranque> {
  /// Crea la vista inicial sin acceder directamente a SQLite o almacenamiento seguro.
  const VistaArranque({super.key});

  /// Representa progreso o fallo público para evitar un arranque silenciosamente bloqueado.
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
