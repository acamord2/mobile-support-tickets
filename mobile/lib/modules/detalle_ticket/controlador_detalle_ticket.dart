import '../../app/services/servicio_sincronizacion.dart';
import 'dart:async';
import '../../app/database/repositorio_coordinacion.dart';
import 'package:get/get.dart';
import '../../app/constants/textos_app.dart';
import '../../app/database/repositorio_tickets.dart';
import '../../app/database/repositorio_sucursales.dart';
import '../../app/database/repositorio_evidencias.dart';
import '../../app/routes/rutas.dart';
import '../../app/database/repositorio_eventos.dart';
import '../../models/tipo_solicitud_estado.dart';
import '../../app/database/repositorio_solicitudes.dart';
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
  final tecnicos = <Map<String, Object?>>[].obs;
  final tecnicoSeleccionado = Rxn<int>();
  Worker? _estadoSync;
  int get rol => _sesion.usuario?.roleId ?? 2;
  bool get tecnicoAutorizado =>
      rol == 1 ||
      ((rol == 2 || rol == 3) &&
          ticket.value?.tecnicoId == _sesion.usuario?.id);
  bool get puedeAsignar =>
      (rol == 1 || rol == 3) &&
      ticket.value != null &&
      ticket.value!.estado != 'Resolved' &&
      ticket.value!.estado != 'Cancelled';

  /// Persiste asignación y evento antes de pedir sincronización oportunista, sin esperar API.
  Future<void> asignar() async {
    final actual = ticket.value, usuario = _sesion.usuario;
    if (!puedeAsignar ||
        guardando.value ||
        actual == null ||
        usuario == null ||
        tecnicoSeleccionado.value == null) {
      return;
    }
    guardando.value = true;
    error.value = '';
    try {
      await RepositorioCoordinacion(_tickets.sql).asignar(
        actual.idLocal,
        usuario.id,
        rol,
        tecnicoSeleccionado.value!,
        usuario.name,
      );
      await cargar(actual.idLocal);
      if (Get.isRegistered<ServicioSincronizacion>()) {
        Get.find<ServicioSincronizacion>().solicitarAutomatica();
      }
    } catch (_) {
      error.value = TextosApp.errorAsignacion;
    } finally {
      guardando.value = false;
    }
  }

  final solicitudes = <Map<String, Object?>>[].obs;
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
    if (Get.isRegistered<ServicioSincronizacion>()) {
      _estadoSync = ever(Get.find<ServicioSincronizacion>().estado, (
        EstadoSincronizacionActual estado,
      ) {
        if (estado != EstadoSincronizacionActual.sincronizando &&
            _id != null &&
            !isClosed) {
          unawaited(cargar(_id!));
        }
      });
    }
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
      if (rol == 1 || rol == 3) {
        tecnicos.assignAll(
          await RepositorioCoordinacion(_tickets.sql).listar(usuario),
        );
        if (rol == 3) {
          tecnicos.add({
            'id': usuario,
            'nombre': '${_sesion.usuario!.name} (yo)',
            'coordinador_id': usuario,
          });
        }
        tecnicoSeleccionado.value =
            tecnicos.any((t) => t['id'] == local.tecnicoId)
            ? local.tecnicoId
            : null;
      }
      solicitudes.assignAll(
        await RepositorioSolicitudes(_tickets.sql).listar(usuario, ticket: id),
      );
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
  bool get puedeComenzar =>
      tecnicoAutorizado && ticket.value?.estado == 'Pending';
  bool get puedeEditar =>
      (rol == 1 || rol == 3) &&
      ticket.value != null &&
      ticket.value!.estado != 'Resolved' &&
      ticket.value!.estado != 'Cancelled';
  bool get puedeSeguir =>
      tecnicoAutorizado && ticket.value?.estado == 'InProgress';

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

  /// Solo solicita una decisión; el ticket permanece en su estado hasta revisión de coordinación.
  bool get puedeSolicitar =>
      ticket.value != null &&
      ticket.value!.estado != 'Resolved' &&
      ticket.value!.estado != 'Cancelled' &&
      (rol == 1 ||
          tecnicoAutorizado ||
          (rol == 4 && ticket.value!.reportanteId == _sesion.usuario?.id));
  bool get puedeRevisar => rol == 1 || rol == 3;
  Future<void> solicitar(TipoSolicitudEstado tipo) async {
    if (!puedeSolicitar || guardando.value) return;
    await Get.toNamed(
      Rutas.solicitarEstado,
      arguments: {'ticket': _id, 'tipo': tipo},
    );
    if (!isClosed && _id != null) await cargar(_id!);
  }

  /// Guarda decisión local y refresca UI antes del intento remoto; API volverá a validar alcance.
  Future<void> revisar(int id, bool aprobar) async {
    if (!puedeRevisar || guardando.value) return;
    guardando.value = true;
    error.value = '';
    try {
      await RepositorioSolicitudes(
        _tickets.sql,
      ).revisar(id, _sesion.usuario!.id, rol, _sesion.usuario!.name, aprobar);
      await cargar(_id!);
      if (Get.isRegistered<ServicioSincronizacion>()) {
        Get.find<ServicioSincronizacion>().solicitarAutomatica();
      }
    } catch (_) {
      error.value = 'No se pudo guardar la revisión.';
    } finally {
      guardando.value = false;
    }
  }

  @override
  void onClose() {
    _estadoSync?.dispose();
    super.onClose();
  }

  String get estadoTexto => switch (ticket.value?.estado) {
    'Pending' => TextosApp.ticketPendiente,
    'InProgress' => TextosApp.enAtencion,
    'Resolved' => TextosApp.ticketResuelto,
    'Cancelled' => 'Cancelado',
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
      if (Get.isRegistered<ServicioSincronizacion>()) {
        Get.find<ServicioSincronizacion>().solicitarAutomatica();
      }
    } catch (_) {
      if (!isClosed) error.value = TextosApp.errorComenzarAtencion;
    } finally {
      if (!isClosed) guardando.value = false;
    }
  }
}
