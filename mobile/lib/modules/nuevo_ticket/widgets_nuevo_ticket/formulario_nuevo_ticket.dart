import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';
import '../controlador_nuevo_ticket.dart';

/// Representa el formulario y remite sus eventos al controller; no consulta API,
/// SQLite ni comprime imágenes. Una sola composición visual por archivo.
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
        if (controller.sesion.usuario?.roleId != 4)
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
        if (controller.foto.value != null)
          const Text(TextosApp.fotoPreparada, style: FuentesApp.body),
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
