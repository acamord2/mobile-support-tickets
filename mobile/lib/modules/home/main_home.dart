import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/theme/colores_app.dart';
import '../../app/theme/fuentes_app.dart';
import 'controlador_inicio.dart';
import 'widgets_home/cabecera_inicio.dart';
import 'widgets_home/resumen_agenda.dart';
import 'widgets_home/tarjeta_ticket_agenda.dart';
import 'widgets_home/pie_inicio.dart';
import '../../app/services/servicio_sincronizacion.dart';

/// Compone Mi agenda con estado recibido del controller; toda información de negocio
/// viene del repositorio SQLite, incluso después de sincronizar o crear offline.
class VistaInicio extends GetView<ControladorInicio> {
  const VistaInicio({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
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
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    CabeceraInicio(nombreTecnico: controller.nombreTecnico),
                    Text(controller.fechaActual, style: FuentesApp.body),
                    const SizedBox(height: 16),
                    Obx(
                      () => ResumenAgenda(conteos: Map.of(controller.conteos)),
                    ),
                    const SizedBox(height: 16),
                    Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            controller.estadoTexto,
                            style: FuentesApp.estadoModulo,
                          ),
                          OutlinedButton(
                            onPressed:
                                controller.sincronizacion?.estado.value ==
                                    EstadoSincronizacionActual.sincronizando
                                ? null
                                : controller.sincronizar,
                            child: const Text(TextosApp.sincronizar),
                          ),
                          if (controller.error.value.isNotEmpty)
                            Text(
                              controller.error.value,
                              style: FuentesApp.error,
                            ),
                          if (controller.agenda.isEmpty)
                            const Text(
                              TextosApp.sinTickets,
                              style: FuentesApp.body,
                            ),
                          ...controller.agenda.map(
                            (t) => TarjetaTicketAgenda(
                              ticket: t,
                              sucursal: controller.nombreSucursal(t.sucursalId),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: PieInicio(alCerrarSesion: controller.cerrarSesion),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
