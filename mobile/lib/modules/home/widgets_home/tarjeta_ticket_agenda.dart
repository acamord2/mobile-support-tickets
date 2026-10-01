import 'package:flutter/material.dart';
import '../../../models/ticket_local.dart';
import '../../../app/constants/textos_app.dart';
import '../../../app/theme/fuentes_app.dart';

/// Muestra programación local, problema, sucursal y estado sin consultar servicios.
class TarjetaTicketAgenda extends StatelessWidget {
  final TicketLocal ticket;
  final String sucursal;
  const TarjetaTicketAgenda({
    super.key,
    required this.ticket,
    required this.sucursal,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TimeOfDay.fromDateTime(ticket.programado.toLocal()).format(context),
            style: FuentesApp.body,
          ),
          Text(ticket.titulo, style: FuentesApp.tituloTarjeta),
          Text(sucursal, style: FuentesApp.body),
          Text(switch (ticket.estado) {
            'Pending' => TextosApp.pendientes,
            'InProgress' => TextosApp.enAtencion,
            _ => TextosApp.resueltos,
          }, style: FuentesApp.estadoModulo),
          if (ticket.syncStatus == 'pending')
            const Text(
              TextosApp.pendienteLocal,
              style: FuentesApp.estadoModulo,
            ),
        ],
      ),
    ),
  );
}
