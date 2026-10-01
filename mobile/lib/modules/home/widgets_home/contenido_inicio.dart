import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';
import '../controlador_inicio.dart';

/// Muestra la identidad pública de la sesión y enlaza logout al controller.
/// Usa GetView para mantener servicios, token y navegación fuera del widget.
class ContenidoInicio extends GetView<ControladorInicio> {
  /// Crea el contenido neutral de Home sin dependencias de otros módulos.
  const ContenidoInicio({super.key});

  /// Presenta bienvenida, nombre y botón con estilos reutilizados.
  /// No transforma datos ni ejecuta acciones durante la construcción.
  @override
  Widget build(BuildContext context) => Column(
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
  );
}
