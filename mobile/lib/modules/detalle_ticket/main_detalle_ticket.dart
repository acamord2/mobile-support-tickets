import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/theme/colores_app.dart';
import '../../app/theme/fuentes_app.dart';
import 'controlador_detalle_ticket.dart';
import '../../models/tipo_solicitud_estado.dart';
import 'widgets_detalle_ticket/informacion_detalle_ticket.dart';
import 'widgets_detalle_ticket/accion_detalle_ticket.dart';
import 'widgets_detalle_ticket/seguimiento_ticket.dart';

class VistaDetalleTicket extends GetView<ControladorDetalleTicket> {
  const VistaDetalleTicket({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ColoresApp.background,
    appBar: AppBar(
      title: const Text(TextosApp.detalleTicket),
      leading: BackButton(onPressed: () => Get.back<void>()),
    ),
    body: Obx(() {
      if (controller.cargando.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final ticket = controller.ticket.value;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (controller.error.value.isNotEmpty)
                Text(controller.error.value, style: FuentesApp.error),
              if (ticket != null) ...[
                InformacionDetalleTicket(
                  ticket: ticket,
                  sucursal: controller.sucursal.value,
                  estado: controller.estadoTexto,
                ),
                const SizedBox(height: 24),
                Text(
                  ticket.tecnicoId == null
                      ? TextosApp.ticketSinAsignar
                      : '${TextosApp.tecnicoAsignado}: #${ticket.tecnicoId}',
                  style: FuentesApp.body,
                ),
                if (controller.puedeAsignar) ...[
                  DropdownButton<int>(
                    isExpanded: true,
                    value: controller.tecnicoSeleccionado.value,
                    hint: const Text(TextosApp.seleccionarTecnico),
                    items: controller.tecnicos
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['id'] as int,
                            child: Text(t['nombre'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: controller.guardando.value
                        ? null
                        : (id) => controller.tecnicoSeleccionado.value = id,
                  ),
                  OutlinedButton(
                    onPressed: controller.guardando.value
                        ? null
                        : controller.asignar,
                    child: Text(
                      ticket.tecnicoId == null
                          ? TextosApp.asignarTecnico
                          : TextosApp.reasignarTecnico,
                    ),
                  ),
                ],
                if (controller.puedeEditar)
                  OutlinedButton(
                    onPressed: controller.guardando.value
                        ? null
                        : controller.editar,
                    child: Text(
                      ticket.programado == null
                          ? 'Programar atención'
                          : 'Reprogramar atención',
                    ),
                  ),
                AccionDetalleTicket(
                  puedeComenzar: controller.puedeComenzar,
                  guardando: controller.guardando.value,
                  estado: controller.estadoTexto,
                  alComenzar: controller.comenzarAtencion,
                ),
                if (controller.puedeSeguir) ...[
                  OutlinedButton(
                    onPressed: controller.guardando.value
                        ? null
                        : controller.agregarSeguimiento,
                    child: const Text(TextosApp.agregarSeguimiento),
                  ),
                ],
                if (controller.puedeSolicitar) ...[
                  OutlinedButton(
                    onPressed: controller.guardando.value
                        ? null
                        : () => controller.solicitar(
                            TipoSolicitudEstado.resolucion,
                          ),
                    child: const Text('Solicitar resolución'),
                  ),
                  OutlinedButton(
                    onPressed: controller.guardando.value
                        ? null
                        : () => controller.solicitar(
                            TipoSolicitudEstado.cancelacion,
                          ),
                    child: const Text('Solicitar cancelación'),
                  ),
                ],
                for (final s in controller.solicitudes)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s['tipo'] == TipoSolicitudEstado.resolucion.clave ? "Resolución" : "Cancelación"} · ${s['estado']}',
                          ),
                          Text(
                            'Solicitante: ${s['requester_name'] ?? s['requester_user_id']}',
                          ),
                          Text(
                            'Fecha: ${DateTime.parse(s['created_at'] as String).toLocal()}',
                          ),
                          Text(s['motivo'] as String? ?? 'Sin comentario'),
                          if (s['reviewed_by_user_id'] != null)
                            Text(
                              'Revisor: ${s['reviewer_name'] ?? s['reviewed_by_user_id']} · ${s['reviewed_at']}',
                            ),
                          if (s['sync_status'] == 'pending')
                            const Text('Pendiente de sincronizar'),
                          if (controller.puedeRevisar &&
                              s['estado'] == EstadoSolicitud.pendiente.clave)
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: controller.guardando.value
                                      ? null
                                      : () => controller.revisar(
                                          s['id_local'] as int,
                                          true,
                                        ),
                                  child: const Text('Aprobar'),
                                ),
                                OutlinedButton(
                                  onPressed: controller.guardando.value
                                      ? null
                                      : () => controller.revisar(
                                          s['id_local'] as int,
                                          false,
                                        ),
                                  child: const Text('Rechazar'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                SeguimientoTicket(
                  registros: controller.seguimientos.toList(),
                  evidencias: controller.evidenciasDisponibles.toList(),
                ),
              ],
            ],
          ),
        ),
      );
    }),
  );
}
