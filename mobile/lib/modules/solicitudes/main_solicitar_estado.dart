import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/tipo_solicitud_estado.dart';
import 'controlador_solicitar_estado.dart';

class VistaSolicitarEstado extends GetView<ControladorSolicitarEstado> {
  const VistaSolicitarEstado({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Solicitar ${controller.tipo.texto.toLowerCase()}'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'El ticket conservará su estado hasta que Coordinador o Administrador revise la solicitud.',
            ),
            TextField(
              controller: controller.motivo,
              maxLength: 10000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: controller.tipo == TipoSolicitudEstado.cancelacion
                    ? 'Motivo obligatorio'
                    : 'Comentario opcional',
              ),
            ),
            if (controller.error.value.isNotEmpty)
              Text(
                controller.error.value,
                style: const TextStyle(color: Colors.red),
              ),
            FilledButton(
              onPressed: controller.ocupado.value ? null : controller.guardar,
              child: Text(
                controller.ocupado.value ? 'Guardando' : 'Guardar solicitud',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
