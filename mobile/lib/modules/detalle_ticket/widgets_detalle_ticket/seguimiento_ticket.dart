import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/colores_app.dart';
import '../../../app/theme/fuentes_app.dart';
import '../../../models/tipo_evento_ticket.dart';
import '../../../widgets/foto_procesada.dart';

/// Representa cronología local de más antiguo a reciente con autor persistido.
/// La foto se obtiene del enlace a Evidence, sin Base64 dentro del evento.
class SeguimientoTicket extends StatelessWidget {
  final List<Map<String, Object?>> registros;
  final List<Map<String, Object?>> evidencias;
  const SeguimientoTicket({
    super.key,
    required this.registros,
    this.evidencias = const [],
  });

  String _fecha(Object fecha) =>
      DateTime.parse(fecha as String).toLocal().toString().split('.').first;
  String _titulo(String tipo) {
    final etiquetas = {
      TipoEventoTicket.creado.clave: TextosApp.eventoCreado,
      TipoEventoTicket.programado.clave: TextosApp.eventoProgramado,
      TipoEventoTicket.reprogramado.clave: TextosApp.eventoReprogramado,
      TipoEventoTicket.enAtencion.clave: TextosApp.eventoEnAtencion,
      TipoEventoTicket.seguimiento.clave: TextosApp.seguimiento,
      TipoEventoTicket.resuelto.clave: TextosApp.eventoResuelto,
      TipoEventoTicket.asignado.clave: TextosApp.eventoAsignado,
      TipoEventoTicket.reasignado.clave: TextosApp.eventoReasignado,
      TipoEventoTicket.solicitudResolucion.clave: 'Solicitud de resolución',
      TipoEventoTicket.solicitudCancelacion.clave: 'Solicitud de cancelación',
      TipoEventoTicket.resolucionAprobada.clave: 'Resolución aprobada',
      TipoEventoTicket.resolucionRechazada.clave: 'Resolución rechazada',
      TipoEventoTicket.cancelacionAprobada.clave: 'Cancelación aprobada',
      TipoEventoTicket.cancelacionRechazada.clave: 'Cancelación rechazada',
      TipoEventoTicket.cancelado.clave: 'Ticket cancelado',
    };
    return etiquetas[tipo] ?? tipo;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(TextosApp.seguimiento, style: FuentesApp.tituloTarjeta),
      if (registros.isEmpty)
        const Text(TextosApp.sinSeguimiento, style: FuentesApp.body),
      for (final e in registros)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.circle, size: 12, color: ColoresApp.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 12, bottom: 16),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: ColoresApp.borde)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titulo(e['tipo_evento'] as String),
                        style: FuentesApp.tituloTarjeta,
                      ),
                      Text(
                        _fecha(e['created_at']!),
                        style: FuentesApp.estadoModulo,
                      ),
                      Text(
                        e['usuario_nombre'] as String? ??
                            '${TextosApp.autorEvento} #${e['autor_id']}',
                        style: FuentesApp.estadoModulo,
                      ),
                      if ((e['descripcion'] as String).isNotEmpty)
                        Text(
                          e['descripcion'] as String,
                          style: FuentesApp.body,
                        ),
                      if (e['previous_scheduled_at'] != null)
                        Text(
                          '${TextosApp.programacionAnterior}: ${_fecha(e['previous_scheduled_at']!)}',
                          style: FuentesApp.body,
                        ),
                      if (e['scheduled_at'] != null)
                        Text(
                          '${TextosApp.programacionNueva}: ${_fecha(e['scheduled_at']!)}',
                          style: FuentesApp.body,
                        ),
                      if (e['photo_base64'] is String)
                        FotoProcesada(base64: e['photo_base64'] as String),
                      if (e['sync_status'] == 'pending')
                        const Text(
                          TextosApp.pendienteLocal,
                          style: FuentesApp.estadoModulo,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      if (evidencias.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text(
          TextosApp.evidenciasDisponibles,
          style: FuentesApp.tituloTarjeta,
        ),
        for (final evidencia in evidencias)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evidencia['descripcion'] as String,
                  style: FuentesApp.body,
                ),
                Text(
                  _fecha(evidencia['created_at']!),
                  style: FuentesApp.estadoModulo,
                ),
                if (evidencia['photo_base64'] is String)
                  FotoProcesada(base64: evidencia['photo_base64'] as String),
              ],
            ),
          ),
      ],
    ],
  );
}
