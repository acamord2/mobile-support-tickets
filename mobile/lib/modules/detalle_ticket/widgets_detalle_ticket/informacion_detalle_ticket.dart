import 'package:flutter/material.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/colores_app.dart';
import '../../../app/theme/fuentes_app.dart';
import '../../../models/ticket_local.dart';
import '../../../models/sucursal_local.dart';

/// Presenta campos locales recibidos y fechas en horario del teléfono.
/// Omite sucursal no descargada y no crea información o historial ficticios.
class InformacionDetalleTicket extends StatelessWidget {
  final TicketLocal ticket;
  final SucursalLocal? sucursal;
  final String estado;
  const InformacionDetalleTicket({
    super.key,
    required this.ticket,
    required this.sucursal,
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = ticket.programado.toLocal();
    final dia =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: Text(estado),
          side: const BorderSide(color: ColoresApp.borde),
        ),
        const SizedBox(height: 12),
        Text(
          '${TextosApp.identificadorTicket}: ${ticket.idRemoto ?? ticket.idLocal}',
          style: FuentesApp.estadoModulo,
        ),
        if (ticket.idRemoto == null)
          const Text(
            TextosApp.identificadorLocal,
            style: FuentesApp.estadoModulo,
          ),
        const SizedBox(height: 20),
        const Text(TextosApp.problemaTicket, style: FuentesApp.estadoModulo),
        Text(ticket.titulo, style: FuentesApp.title),
        if (sucursal != null) ...[
          const SizedBox(height: 20),
          const Text(TextosApp.sucursal, style: FuentesApp.estadoModulo),
          Text(sucursal!.nombre, style: FuentesApp.body),
          Text(sucursal!.direccion, style: FuentesApp.body),
        ],
        const SizedBox(height: 20),
        const Text(
          TextosApp.atencionProgramada,
          style: FuentesApp.estadoModulo,
        ),
        Text(
          '$dia ${TimeOfDay.fromDateTime(fecha).format(context)}',
          style: FuentesApp.body,
        ),
        const SizedBox(height: 20),
        const Text(TextosApp.descripcion, style: FuentesApp.estadoModulo),
        Text(ticket.descripcion, style: FuentesApp.body),
        if (ticket.syncStatus == 'pending') ...[
          const SizedBox(height: 20),
          const Text(TextosApp.pendienteLocal, style: FuentesApp.estadoModulo),
        ],
      ],
    );
  }
}
