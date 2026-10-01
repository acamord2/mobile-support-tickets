import 'dart:async';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/database/repositorio_tickets.dart';
import '../../app/database/repositorio_sucursales.dart';
import '../../app/database/repositorio_evidencias.dart';
import '../../app/routes/rutas.dart';
import '../../app/database/repositorio_eventos.dart';
import '../../models/tipo_evento_ticket.dart';
import '../../app/services/servicio_sesion.dart';
import '../../models/ticket_local.dart';
import '../../models/sucursal_local.dart';

/// Recupera detalle del propietario exclusivamente de SQLite y coordina atención local.
/// Reutiliza actualización/cola existentes sin HTTP ni nuevas transiciones.
class ControladorDetalleTicket extends GetxController {
  final RepositorioTickets _tickets;
  final RepositorioSucursales _sucursales;
  final ServicioSesion _sesion;
  final RepositorioEvidencias _evidencias;
  final seguimientos = <Map<String, Object?>>[].obs;
  final evidenciasDisponibles = <Map<String, Object?>>[].obs;
  final ticket = Rxn<TicketLocal>();
  final sucursal = Rxn<SucursalLocal>();
  final cargando = false.obs;
  final guardando = false.obs;
  final error = ''.obs;
  int? _id;
  ControladorDetalleTicket(
    this._tickets,
    this._sucursales,
    this._sesion,
    this._evidencias,
  );

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
      final registros = await RepositorioEventos(
        _evidencias.sql,
      ).listar(id, usuario);
      final fotos = await _evidencias.listar(id, usuario);
      if (isClosed || _sesion.usuario?.id != usuario) return;
      ticket.value = local;
      seguimientos.assignAll(registros);
      evidenciasDisponibles.assignAll(
        fotos.where(
          (foto) => !registros.any(
            (evento) => evento['evidencia_id_local'] == foto['id_local'],
          ),
        ),
      );
      sucursal.value = catalogo.firstWhereOrNull(
        (s) => s.id == local.sucursalId,
      );
    } catch (_) {
      if (!isClosed) {
        ticket.value = null;
        sucursal.value = null;
        seguimientos.clear();
        evidenciasDisponibles.clear();
        error.value = TextosApp.ticketNoDisponible;
      }
    } finally {
      if (!isClosed) cargando.value = false;
    }
  }

  /// Deriva textos públicos y disponibilidad de la única transición autorizada.
  bool get puedeComenzar => ticket.value?.estado == 'Pending';
  bool get puedeEditar =>
      ticket.value != null && ticket.value!.estado != 'Resolved';
  bool get puedeSeguir => ticket.value?.estado == 'InProgress';

  /// Abre formularios por Id local y recarga SQLite al regresar, sin sincronizar.
  Future<void> editar() async {
    if (!puedeEditar || guardando.value) return;
    await Get.toNamed<void>(Rutas.editarTicket, arguments: _id);
    if (!isClosed && _id != null) await cargar(_id!);
  }

  /// Añade seguimiento solo En atención; el formulario conserva autoría y estado.
  Future<void> agregarSeguimiento() async {
    if (!puedeSeguir || guardando.value) return;
    await Get.toNamed<void>(Rutas.seguimiento, arguments: _id);
    if (!isClosed && _id != null) await cargar(_id!);
  }

  /// Exige seguimiento manual existente y persiste Resolved con la cola actual.
  /// No exige fotografía ni admite reabrir o retroceder estados.
  Future<void> resolver() async {
    if (guardando.value || !puedeSeguir) return;
    final id = _id, usuario = _sesion.usuario?.id;
    if (id == null || usuario == null) return;
    guardando.value = true;
    error.value = '';
    try {
      final actual = await _tickets.obtener(id, usuario);
      if (actual == null ||
          actual.estado != 'InProgress' ||
          _sesion.usuario?.id != usuario) {
        throw StateError('Ticket no autorizado.');
      }
      final registros = await RepositorioEventos(
        _tickets.sql,
      ).listar(id, usuario);
      if (!registros.any(
        (e) => e['tipo_evento'] == TipoEventoTicket.seguimiento.clave,
      )) {
        error.value = TextosApp.faltaSeguimiento;
        return;
      }
      await _tickets.actualizar(
        id,
        usuario,
        titulo: actual.titulo,
        descripcion: actual.descripcion,
        estado: 'Resolved',
        programado: actual.programado,
        autorNombre: _sesion.usuario!.name,
      );
      await cargar(id);
    } catch (_) {
      if (!isClosed) error.value = TextosApp.errorResolver;
    } finally {
      if (!isClosed) guardando.value = false;
    }
  }

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
          autorNombre: _sesion.usuario!.name,
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
