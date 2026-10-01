import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/theme/fuentes_app.dart';
import 'controlador_editar_ticket.dart';

/// Compone edición sencilla y remite eventos al controller sin lógica de negocio.
class VistaEditarTicket extends GetView<ControladorEditarTicket> {
  const VistaEditarTicket({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(TextosApp.editarTicket)),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller.titulo,
                maxLength: 200,
                decoration: const InputDecoration(labelText: TextosApp.titulo),
              ),
              TextField(
                controller: controller.descripcion,
                maxLength: 10000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: TextosApp.descripcion,
                ),
              ),
              OutlinedButton(
                onPressed: controller.ocupado.value
                    ? null
                    : () => controller.fecha(context),
                child: Text(
                  '${TextosApp.fecha}: ${controller.programado.value.toString().split(' ').first}',
                ),
              ),
              OutlinedButton(
                onPressed: controller.ocupado.value
                    ? null
                    : () => controller.hora(context),
                child: Text(
                  '${TextosApp.hora}: ${TimeOfDay.fromDateTime(controller.programado.value).format(context)}',
                ),
              ),
              if (controller.error.value.isNotEmpty)
                Text(controller.error.value, style: FuentesApp.error),
              FilledButton(
                onPressed:
                    controller.ocupado.value || !controller.disponible.value
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
