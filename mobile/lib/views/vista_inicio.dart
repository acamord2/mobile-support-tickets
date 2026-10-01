import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/constants/textos_app.dart';
import '../app/theme/colores_app.dart';
import '../app/theme/fuentes_app.dart';
import '../controllers/controlador_inicio.dart';

/// Demuestra la sesión autenticada mostrando únicamente la identidad pública.
/// Delega logout al controlador y no contiene módulos de tickets ni acceso a JWT.
class VistaInicio extends GetView<ControladorInicio> {
  /// Construye la pantalla neutra con dependencias resueltas por GetX.
  /// Evita crear sesiones o controllers en la presentación.
  const VistaInicio({super.key});

  /// Muestra bienvenida, nombre del técnico y acción de salida con estilos centrales.
  /// Si no hay identidad, el controlador devuelve al login; no se muestra el token.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(TextosApp.bienvenida, style: FuentesApp.title),
                const SizedBox(height: 12),
                Text(controller.usuario?.name ?? '', style: FuentesApp.body),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: controller.cerrarSesion,
                  child: const Text(TextosApp.cerrarSesion),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
