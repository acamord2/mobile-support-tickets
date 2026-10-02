import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/constants/textos_app.dart';
import '../../app/theme/fuentes_app.dart';
import 'controlador_seguimiento.dart';
import '../../widgets/foto_procesada.dart';

class VistaSeguimiento extends GetView<ControladorSeguimiento> {
  const VistaSeguimiento({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(TextosApp.agregarSeguimiento)),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller.descripcion,
                maxLength: 10000,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: TextosApp.trabajoRealizado,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controller.ocupado.value
                        ? null
                        : () => controller.seleccionar(ImageSource.camera),
                    child: const Text(TextosApp.camara),
                  ),
                  OutlinedButton(
                    onPressed: controller.ocupado.value
                        ? null
                        : () => controller.seleccionar(ImageSource.gallery),
                    child: const Text(TextosApp.galeria),
                  ),
                ],
              ),
              if (controller.foto.value != null) ...[
                const Text(TextosApp.previewFoto, style: FuentesApp.body),
                FotoProcesada(base64: controller.foto.value!.base64),
                OutlinedButton(
                  onPressed: controller.ocupado.value
                      ? null
                      : () => controller.seleccionar(ImageSource.gallery),
                  child: const Text('Cambiar foto'),
                ),
                OutlinedButton(
                  onPressed: controller.ocupado.value
                      ? null
                      : controller.quitarFoto,
                  child: const Text(TextosApp.quitarFoto),
                ),
              ],
              if (controller.error.value.isNotEmpty)
                Text(controller.error.value, style: FuentesApp.error),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.ocupado.value
                    ? null
                    : () => controller.guardar(),
                child: Text(
                  controller.ocupado.value
                      ? TextosApp.guardando
                      : TextosApp.guardar,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
