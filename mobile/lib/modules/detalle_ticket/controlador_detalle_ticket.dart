import 'dart:async';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/database/repositorio_tickets.dart';
import '../../app/database/repositorio_sucursales.dart';
import '../../app/services/servicio_sesion.dart';
import '../../models/ticket_local.dart';
import '../../models/sucursal_local.dart';

/// Recupera detalle del propietario exclusivamente de SQLite y coordina atención local.
/// Reutiliza actualización/cola existentes sin HTTP ni nuevas transiciones.
class ControladorDetalleTicket extends GetxController {
  final RepositorioTickets _tickets;
  final RepositorioSucursales _sucursales;
  final ServicioSesion _sesion;
  final ticket = Rxn<TicketLocal>();
  final sucursal = Rxn<SucursalLocal>();
  final cargando = false.obs;
  final guardando = false.obs;
  final error = ''.obs;
  int? _id;
  ControladorDetalleTicket(this._tickets, this._sucursales, this._sesion);

  @override
  void onReady() {
    super.onReady();
    final argumento = Get.arguments;
    if (argumento is int && argumento > 0) {
      unawaited(cargar(argumento));
    } else {
      error.value = TextosApp.ticketNoDisponible;
    }
  }

  /// Carga por Id local y cuenta actual; un ticket ausente/ajeno nunca se representa.
  Future<void> cargar(int id) async {
    _id = id;
    cargando.value = true;
    error.value = '';
    try {
      final usuario = _sesion.usuario?.id;
      if (usuario == null) throw StateError('Sin identidad local.');
      final local = await _tickets.obtener(id, usuario);
      if (local == null) throw StateError('Ticket no disponible.');
      final catalogo = await _sucursales.obtener(usuario);
      if (isClosed || _sesion.usuario?.id != usuario) return;
      ticket.value = local;
      sucursal.value = catalogo.firstWhereOrNull(
        (s) => s.id == local.sucursalId,
      );
    } catch (_) {
      if (!isClosed) {
        ticket.value = null;
        sucursal.value = null;
        error.value = TextosApp.ticketNoDisponible;
      }
    } finally {
      if (!isClosed) cargando.value = false;
    }
  }

  /// Deriva textos públicos y disponibilidad de la única transición autorizada.
  bool get puedeComenzar => ticket.value?.estado == 'Pending';
  String get estadoTexto => switch (ticket.value?.estado) {
    'Pending' => TextosApp.ticketPendiente,
    'InProgress' => TextosApp.enAtencion,
    'Resolved' => TextosApp.ticketResuelto,
    _ => '',
  };

  /// Relee el estado y guarda negocio+cola atómicamente antes de refrescar UI.
  /// Bloquea doble pulsación; no inicia sincronización ni espera respuesta remota.
  Future<void> comenzarAtencion() async {
    if (guardando.value || !puedeComenzar) return;
    final id = _id, usuario = _sesion.usuario?.id;
    if (id == null || usuario == null) return;
    guardando.value = true;
    error.value = '';
    try {
      final actual = await _tickets.obtener(id, usuario);
      if (actual == null || _sesion.usuario?.id != usuario) {
        throw StateError('Ticket no autorizado.');
      }
      if (actual.estado == 'Pending') {
        await _tickets.actualizar(
          id,
          usuario,
          titulo: actual.titulo,
          descripcion: actual.descripcion,
          estado: 'InProgress',
          programado: actual.programado,
        );
      }
      await cargar(id);
    } catch (_) {
      if (!isClosed) error.value = TextosApp.errorComenzarAtencion;
    } finally {
      if (!isClosed) guardando.value = false;
    }
  }
}
