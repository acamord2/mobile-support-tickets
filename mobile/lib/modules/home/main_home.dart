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

/// Compone Home desde estado local del controller y delega todas sus acciones.
/// Separa cabecera, identidad, filtros y lista sin añadir consultas ni fechas.
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
                Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controller.mostrarEquipo) ...[
                        Text(
                          controller.rol == 1
                              ? TextosApp.tecnicos
                              : TextosApp.tecnicosACargo,
                          style: FuentesApp.tituloTarjeta,
                        ),
                        OutlinedButton(
                          onPressed: () => controller.seleccionarTecnico(
                            null,
                            noAsignados: true,
                          ),
                          child: const Text(TextosApp.ticketsSinAsignar),
                        ),
                        if (controller.rol == 1)
                          OutlinedButton(
                            onPressed: () => controller.seleccionarTecnico(
                              null,
                              global: true,
                            ),
                            child: const Text(TextosApp.todosLosTickets),
                          ),
                        for (final tecnico in controller.tecnicos)
                          Card(
                            child: ListTile(
                              title: Text(tecnico['nombre'] as String),
                              subtitle: Text(
                                controller.resumenTecnico(tecnico['id'] as int),
                              ),
                              onTap: () => controller.seleccionarTecnico(
                                tecnico['id'] as int,
                              ),
                            ),
                          ),
                      ] else ...[
                        if (controller.esCoordinacion)
                          TextButton.icon(
                            onPressed: () =>
                                controller.seleccionarTecnico(null),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text(TextosApp.volverAlEquipo),
                          ),
                        if (controller.rol == 4)
                          const Text(
                            TextosApp.misReportes,
                            style: FuentesApp.tituloTarjeta,
                          ),
                      ],
                    ],
                  ),
                ),
                Obx(
                  () => controller.mostrarEquipo
                      ? const SizedBox.shrink()
                      : FiltrosAgenda(
                          conteos: Map.of(controller.conteos),
                          seleccionados: controller.filtrosSeleccionados
                              .toSet(),
                          alSeleccionar: controller.alternarFiltro,
                        ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
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
}
