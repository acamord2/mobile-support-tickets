import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/constants/textos_app.dart';
import '../app/theme/colores_app.dart';
import '../app/theme/fuentes_app.dart';
import '../controllers/controlador_login.dart';

/// Presenta los campos y estados del controlador sin conocer HTTP, JSON o tokens.
/// Usa GetView y Obx para inyectar el controlador y actualizar carga/errores;
/// mantiene un formulario sencillo que se adapta al teclado y pantallas pequeñas.
class VistaLogin extends GetView<ControladorLogin> {
  /// Construye la pantalla sin crear servicios o controllers dentro de la vista.
  /// GetX resuelve las dependencias registradas por DependenciasApp.
  const VistaLogin({super.key});

  /// Muestra usuario, contraseña oculta y una acción deshabilitada mientras espera.
  /// Delega validación y envío al controlador y utiliza los textos/estilos centrales
  /// para no repetir infraestructura ni mostrar información sensible.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Obx(
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
                      decoration: const InputDecoration(
                        labelText: TextosApp.contrasena,
                        border: OutlineInputBorder(),
                      ),
                      style: FuentesApp.body,
                      obscureText: true,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
