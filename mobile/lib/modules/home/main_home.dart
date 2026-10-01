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
      floatingActionButton: FloatingActionButton(
        onPressed: controller.nuevo,
        tooltip: TextosApp.nuevoTicket,
        child: const Icon(Icons.add),
      ),
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
                  () => FiltrosAgenda(
                    conteos: Map.of(controller.conteos),
                    seleccionados: controller.filtrosSeleccionados.toSet(),
                    alSeleccionar: controller.alternarFiltro,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Obx(() {
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
