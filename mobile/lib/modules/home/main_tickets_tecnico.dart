import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controlador_inicio.dart';
import 'widgets_home/tarjeta_ticket_agenda.dart';
import 'widgets_home/filtros_agenda.dart';

class VistaTicketsTecnico extends GetView<ControladorInicio> {
  const VistaTicketsTecnico({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tickets del técnico')),
    body: Obx(
      () => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FiltrosAgenda(
            conteos: Map.of(controller.conteos),
            seleccionados: controller.filtrosSeleccionados.toSet(),
            alSeleccionar: controller.alternarFiltro,
          ),
          if (controller.ticketsVisibles.isEmpty)
            const Text('No hay tickets en este filtro.'),
          for (final t in controller.ticketsVisibles)
            TarjetaTicketAgenda(
              ticket: t,
              sucursal: controller.nombreSucursal(t.sucursalId),
              alSeleccionar: () => controller.abrirDetalle(t.idLocal),
            ),
        ],
      ),
    ),
  );
}
