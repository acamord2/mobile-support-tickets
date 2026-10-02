import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/theme/colores_app.dart';
import '../../app/theme/fuentes_app.dart';
import '../../app/services/servicio_sincronizacion.dart';
import 'controlador_inicio.dart';
import 'widgets_home/cabecera_inicio.dart';
import 'widgets_home/filtros_agenda.dart';
import 'widgets_home/tarjeta_ticket_agenda.dart';
import 'widgets_home/card_seccion_coordinador.dart';
import 'seccion_coordinador.dart';
import '../../models/ticket_local.dart';

class VistaInicio extends GetView<ControladorInicio> {
  const VistaInicio({super.key});
  @override
  Widget build(BuildContext context) {
    CabeceraInicio cabecera(bool cargando) => CabeceraInicio(
      nombreTecnico: controller.nombreTecnico,
      saludo: controller.saludo,
      sincronizando: cargando,
      alSincronizar: controller.sincronizar,
      alCerrarSesion: controller.cerrarSesion,
    );
    return Scaffold(
      backgroundColor: ColoresApp.background,
      floatingActionButton: controller.puedeCrear
          ? FloatingActionButton(
              onPressed: controller.nuevo,
              tooltip: TextosApp.nuevoTicket,
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (controller.sincronizacion == null)
                  cabecera(false)
                else
                  Obx(
                    () => cabecera(
                      controller.sincronizacion!.estado.value ==
                          EstadoSincronizacionActual.sincronizando,
                    ),
                  ),
                if (controller.esCoordinacion)
                  Obx(
                    () => Column(
                      children: [
                        CardSeccionCoordinador(
                          titulo: controller.rol == 1
                              ? 'Todos los tickets'
                              : 'Mis tickets',
                          resumen: controller.resumenLista(
                            controller.rol == 1
                                ? controller.agenda
                                : controller.misTickets,
                          ),
                          abierta:
                              controller.seccionAbierta.value ==
                              SeccionCoordinador.misTickets,
                          alAlternar: () => controller.alternarSeccion(
                            SeccionCoordinador.misTickets,
                          ),
                          contenido: _lista(
                            controller.rol == 1
                                ? controller.agenda
                                : controller.misTickets,
                            'No tienes tickets asignados.',
                          ),
                        ),
                        CardSeccionCoordinador(
                          titulo: controller.rol == 1
                              ? 'Técnicos'
                              : 'Técnicos a mi cargo',
                          resumen: '${controller.tecnicos.length} técnicos',
                          abierta:
                              controller.seccionAbierta.value ==
                              SeccionCoordinador.tecnicos,
                          alAlternar: () => controller.alternarSeccion(
                            SeccionCoordinador.tecnicos,
                          ),
                          contenido: Column(
                            children: [
                              for (final t in controller.tecnicos)
                                ListTile(
                                  title: Text(t['nombre'] as String),
                                  subtitle: Text(
                                    controller.resumenTecnico(t['id'] as int),
                                  ),
                                  onTap: () =>
                                      controller.abrirTecnico(t['id'] as int),
                                ),
                            ],
                          ),
                        ),
                        CardSeccionCoordinador(
                          titulo: 'Tickets sin asignar',
                          resumen: '${controller.noAsignados.length} tickets',
                          abierta:
                              controller.seccionAbierta.value ==
                              SeccionCoordinador.sinAsignar,
                          alAlternar: () => controller.alternarSeccion(
                            SeccionCoordinador.sinAsignar,
                          ),
                          contenido: _lista(
                            controller.noAsignados,
                            'No hay tickets sin asignar.',
                          ),
                        ),
                        CardSeccionCoordinador(
                          titulo: 'Solicitudes',
                          resumen:
                              '${controller.solicitudes.length} pendientes',
                          abierta:
                              controller.seccionAbierta.value ==
                              SeccionCoordinador.solicitudes,
                          alAlternar: () => controller.alternarSeccion(
                            SeccionCoordinador.solicitudes,
                          ),
                          contenido: Column(
                            children: [
                              if (controller.solicitudes.isEmpty)
                                const Text('No hay solicitudes pendientes.'),
                              for (final s in controller.solicitudes)
                                ListTile(
                                  title: Text(
                                    '${s['tipo'] == "SOLICITUD_RESOLUCION" ? "Resolución" : "Cancelación"} · ${s['titulo']}',
                                  ),
                                  subtitle: Text(
                                    '${s['requester_name'] ?? s['requester_user_id']} · ${DateTime.parse(s['created_at'] as String).toLocal()}\n${s['motivo'] ?? "Sin comentario"}',
                                  ),
                                  onTap: () => controller.abrirDetalle(
                                    s['ticket_id_local'] as int,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (controller.rol == 4)
                    const Text(
                      TextosApp.misReportes,
                      style: FuentesApp.tituloTarjeta,
                    ),
                  Obx(
                    () => FiltrosAgenda(
                      conteos: Map.of(controller.conteos),
                      seleccionados: controller.filtrosSeleccionados.toSet(),
                      alSeleccionar: controller.alternarFiltro,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                if (!controller.esCoordinacion)
                  Obx(() {
                    if (controller.mostrarEquipo) {
                      return Text(
                        controller.estadoTexto,
                        style: FuentesApp.estadoModulo,
                      );
                    }
                    final visibles = controller.ticketsVisibles;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          controller.estadoTexto,
                          style: FuentesApp.estadoModulo,
                        ),
                        const SizedBox(height: 12),
                        if (controller.error.value.isNotEmpty)
                          Text(controller.error.value, style: FuentesApp.error),
                        if (visibles.isEmpty)
                          Text(
                            controller.filtrosSeleccionados.isEmpty
                                ? TextosApp.sinTickets
                                : TextosApp.sinTicketsFiltrados,
                            style: FuentesApp.body,
                          ),
                        ...visibles.map(
                          (t) => TarjetaTicketAgenda(
                            alSeleccionar: () =>
                                controller.abrirDetalle(t.idLocal),
                            ticket: t,
                            sucursal: controller.nombreSucursal(t.sucursalId),
                          ),
                        ),
                        const SizedBox(height: 72),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lista(List<TicketLocal> tickets, String vacio) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (tickets.isEmpty) Text(vacio),
      for (final t in tickets)
        TarjetaTicketAgenda(
          ticket: t,
          sucursal: controller.nombreSucursal(t.sucursalId),
          alSeleccionar: () => controller.abrirDetalle(t.idLocal),
        ),
    ],
  );
}
