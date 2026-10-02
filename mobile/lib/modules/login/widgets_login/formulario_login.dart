import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';
import '../controlador_login.dart';

/// Presenta campos, carga y errores del controller sin HTTP ni reglas de negocio.
/// Obx actualiza el formulario y los eventos se delegan a ControladorLogin.
class FormularioLogin extends GetView<ControladorLogin> {
  /// Crea el formulario con el controller resuelto por las dependencias GetX.
  const FormularioLogin({super.key});

  /// Compone los campos y botón según el estado ya calculado por el controller.
  /// Oculta contraseña y bloquea interacción durante la carga para mejorar UX.
  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          TextosApp.appName,
          style: FuentesApp.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: controller.usuario,
          enabled: !controller.cargando.value,
          decoration: const InputDecoration(
            labelText: TextosApp.usuario,
            border: OutlineInputBorder(),
          ),
          style: FuentesApp.body,
          textInputAction: TextInputAction.next,
          autocorrect: false,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.contrasena,
          enabled: !controller.cargando.value,
          decoration: InputDecoration(
            labelText: TextosApp.contrasena,
            suffixIcon: IconButton(
              tooltip: controller.mostrarContrasena.value
                  ? 'Ocultar contraseña'
                  : 'Mostrar contraseña',
              icon: Icon(
                controller.mostrarContrasena.value
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () => controller.mostrarContrasena.toggle(),
            ),
            border: OutlineInputBorder(),
          ),
          style: FuentesApp.body,
          obscureText: !controller.mostrarContrasena.value,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.iniciarSesion(),
        ),
        const SizedBox(height: 16),
        if (controller.error.value.isNotEmpty) ...[
          Text(
            controller.error.value,
            style: FuentesApp.error,
            semanticsLabel: controller.error.value,
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: controller.cargando.value
              ? null
              : controller.iniciarSesion,
          child: controller.cargando.value
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    semanticsLabel: TextosApp.autenticando,
                  ),
                )
              : const Text(TextosApp.iniciarSesion),
        ),
      ],
    ),
  );
}
