import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';
import '../controlador_nuevo_ticket.dart';
import '../../../widgets/foto_procesada.dart';

class FormularioNuevoTicket extends GetView<ControladorNuevoTicket> {
  const FormularioNuevoTicket({super.key});
  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.sucursales.isEmpty)
          const Text(TextosApp.sinSucursales, style: FuentesApp.body),
        DropdownButtonFormField<int>(
          initialValue: controller.sucursal.value,
          decoration: const InputDecoration(labelText: TextosApp.sucursal),
          items: controller.sucursales
              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre)))
              .toList(),
          onChanged: controller.ocupado.value
              ? null
              : (id) => controller.sucursal.value = id,
        ),
        TextField(
          controller: controller.titulo,
          maxLength: 200,
          decoration: const InputDecoration(labelText: TextosApp.titulo),
        ),
        TextField(
          controller: controller.descripcion,
          maxLength: 10000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: TextosApp.descripcion),
        ),
        if (controller.sesion.usuario?.roleId == 1) ...[
          OutlinedButton(
            onPressed: () => controller.fecha(context),
            child: Text(
              '${TextosApp.fecha}: ${controller.programado.value.toLocal().toString().split(' ').first}',
            ),
          ),
          OutlinedButton(
            onPressed: () => controller.hora(context),
            child: Text(
              '${TextosApp.hora}: ${TimeOfDay.fromDateTime(controller.programado.value).format(context)}',
            ),
          ),
        ],
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
                : () => controller.foto.value = null,
            child: const Text(TextosApp.quitarFoto),
          ),
        ],
        if (controller.error.value.isNotEmpty)
          Text(controller.error.value, style: FuentesApp.error),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.ocupado.value ? null : controller.guardar,
          child: Text(
            controller.ocupado.value ? TextosApp.guardando : TextosApp.guardar,
          ),
        ),
      ],
    ),
  );
}
