import 'dart:async';
import '../../app/database/repositorio_coordinacion.dart';
import 'filtro_agenda.dart';
import 'seccion_coordinador.dart';
import '../../app/database/repositorio_solicitudes.dart';
import 'package:get/get.dart';
import '../../app/routes/rutas.dart';
import '../../models/usuario.dart';
import '../../models/ticket_local.dart';
import '../../models/sucursal_local.dart';
import '../../app/services/servicio_sesion.dart';
import '../../app/services/servicio_sincronizacion.dart';
import '../../app/services/servicio_conectividad.dart';
import '../../app/database/repositorio_tickets.dart';
import '../../app/database/repositorio_sucursales.dart';
import '../../app/constants/textos_app.dart';

/// Coordina agenda exclusivamente local y eventos de sincronización; el servicio escribe SQLite y después se refresca el repositorio, nunca API hacia widgets.
class ControladorInicio extends GetxController {
  final ServicioSesion _sesion;
  final RepositorioTickets? repositorio;
  final RepositorioSucursales? sucursales;
  final ServicioSincronizacion? sincronizacion;
  final ServicioConectividad? conectividad;
  final agenda = <TicketLocal>[].obs;
  final tecnicos = <Map<String, Object?>>[].obs;
  final seccionAbierta = Rxn<SeccionCoordinador>();
  final solicitudes = <Map<String, Object?>>[].obs;
  final tecnicoSeleccionado = Rxn<int>();
  final sinAsignar = false.obs;
  final todos = false.obs;
  Worker? _estadoSync;
  int get rol => usuario?.roleId ?? 2;
  bool get esCoordinacion => rol == 1 || rol == 3;
  bool get puedeCrear => rol == 1 || rol == 2 || rol == 4;
  bool get mostrarEquipo =>
      tecnicoSeleccionado.value == null &&
      !sinAsignar.value &&
      !todos.value &&
      esCoordinacion;
  List<TicketLocal> get alcance {
    if (!esCoordinacion) return agenda.toList();
    if (sinAsignar.value) {
      return agenda.where((t) => t.tecnicoId == null).toList();
    }
    if (tecnicoSeleccionado.value != null) {
      return agenda
          .where((t) => t.tecnicoId == tecnicoSeleccionado.value)
          .toList();
    }
    return agenda.toList();
  }

  /// Cambia en una sola operación la única sección abierta o cierra la misma al volver a tocarla.
  void alternarSeccion(SeccionCoordinador seccion) {
    seccionAbierta.value = seccionAbierta.value == seccion ? null : seccion;
  }

  /// Resume listas locales sin inventar distribución por zona o sucursal.
  List<TicketLocal> get misTickets =>
      agenda.where((t) => t.tecnicoId == usuario?.id).toList();
  List<TicketLocal> get noAsignados =>
      agenda.where((t) => t.tecnicoId == null).toList();
  String resumenLista(List<TicketLocal> lista) =>
      '${lista.where((t) => t.estado == "Pending").length} pendientes · ${lista.where((t) => t.estado == "InProgress").length} en atención · ${lista.where((t) => t.estado == "Resolved").length} resueltos';

  /// Navega a una lista sencilla y conserva el acordeón al regresar.
  Future<void> abrirTecnico(int id) async {
    seleccionarTecnico(id);
    await Get.toNamed(Rutas.ticketsTecnico);
    if (!isClosed) {
      seleccionarTecnico(null);
      await cargar();
    }
  }

  /// Selecciona alcance local sin descargar datos ni perder los filtros existentes.
  void seleccionarTecnico(
    int? id, {
    bool noAsignados = false,
    bool global = false,
  }) {
    tecnicoSeleccionado.value = id;
    sinAsignar.value = noAsignados;
    todos.value = global;
    actualizarConteos();
  }

  /// Calcula conteos del alcance elegido; los filtros no cambian los totales.
  void actualizarConteos() {
    final resumen = {
      'Pending': 0,
      'InProgress': 0,
      'Resolved': 0,
      'Cancelled': 0,
    };
    for (final t in alcance) {
      resumen[t.estado] = resumen[t.estado]! + 1;
    }
    conteos.assignAll(resumen);
  }

  String resumenTecnico(int id) {
    final lista = agenda.where((t) => t.tecnicoId == id);
    return '${lista.where((t) => t.estado == "Pending").length} pendientes · ${lista.where((t) => t.estado == "InProgress").length} en atención · ${lista.where((t) => t.estado == "Resolved").length} resueltos';
  }

  final filtrosSeleccionados = <FiltroAgenda>{}.obs;

  /// Filtra por unión de estados sin alterar agenda, orden ni conteos totales.
  List<TicketLocal> get ticketsVisibles {
    final seleccion = filtrosSeleccionados.toSet();
    return seleccion.isEmpty
        ? alcance
        : alcance
              .where((t) => seleccion.any((f) => f.estado == t.estado))
              .toList();
  }

  /// Alterna cada filtro independientemente para permitir selección múltiple inmediata.
  void alternarFiltro(FiltroAgenda filtro) {
    if (!filtrosSeleccionados.remove(filtro)) filtrosSeleccionados.add(filtro);
  }

  final catalogo = <SucursalLocal>[].obs;
  final conteos = <String, int>{
    'Pending': 0,
    'InProgress': 0,
    'Resolved': 0,
    'Cancelled': 0,
  }.obs;
  final error = ''.obs;
  Worker? _red;
  bool _cerrando = false;
  ControladorInicio(
    this._sesion, {
    this.repositorio,
    this.sucursales,
    this.sincronizacion,
    this.conectividad,
  });
  Usuario? get usuario => _sesion.usuario;
  String get nombreTecnico => usuario?.name ?? '';

  /// Selecciona un saludo local según la hora sin agregar una fecha al encabezado.
  String get saludo => DateTime.now().hour < 12
      ? TextosApp.buenosDias
      : DateTime.now().hour < 19
      ? TextosApp.buenasTardes
      : TextosApp.buenasNoches;

  /// Traduce estados técnicos reales a mensajes centralizados para la presentación.
  String get estadoTexto {
    if (_sesion.requiereReautenticacion) return TextosApp.reautenticacion;
    return switch (sincronizacion?.estado.value) {
      EstadoSincronizacionActual.sincronizando => TextosApp.sincronizando,
      EstadoSincronizacionActual.actualizado => TextosApp.actualizado,
      EstadoSincronizacionActual.pendientes => TextosApp.pendienteLocal,
      EstadoSincronizacionActual.reautenticacion => TextosApp.reautenticacion,
      EstadoSincronizacionActual.offline => TextosApp.sinConexion,
      EstadoSincronizacionActual.error => TextosApp.errorServidor,
      _ => TextosApp.pendienteLocal,
    };
  }

  @override
  void onReady() {
    super.onReady();
    if (!_sesion.existeSesion) {
      Get.offAllNamed<void>(Rutas.login);
      return;
    }
    if (sincronizacion != null) {
      _estadoSync = ever(sincronizacion!.estado, (
        EstadoSincronizacionActual estado,
      ) {
        if (estado != EstadoSincronizacionActual.sincronizando && !isClosed) {
          unawaited(cargar());
        }
      });
    }
    unawaited(cargar());
    unawaited(sincronizar());
    if (conectividad != null) {
      var anterior = conectividad!.redDisponible.value;
      _red = ever(conectividad!.redDisponible, (bool? actual) {
        if (anterior == false && actual == true) unawaited(sincronizar());
        anterior = actual;
      });
    }
  }

  /// Recupera catálogo, agenda y resumen del propietario desde SQLite.
  Future<void> cargar() async {
    final id = usuario?.id;
    if (id == null || repositorio == null || sucursales == null) return;
    try {
      final lista = await repositorio!.agenda(id);
      final ramas = await sucursales!.obtener(id);
      final equipo = esCoordinacion
          ? await RepositorioCoordinacion(repositorio!.sql).listar(id)
          : <Map<String, Object?>>[];
      if (isClosed || usuario?.id != id) return;
      agenda.assignAll(lista);
      catalogo.assignAll(ramas);
      tecnicos.assignAll(equipo);
      solicitudes.assignAll(
        await RepositorioSolicitudes(
          repositorio!.sql,
        ).listar(id, pendientes: true),
      );
      actualizarConteos();
      if (lista.any((ticket) => ticket.syncStatus == 'pending') &&
          sincronizacion?.estado.value ==
              EstadoSincronizacionActual.actualizado) {
        sincronizacion!.estado.value = EstadoSincronizacionActual.pendientes;
      }
      error.value = '';
    } catch (_) {
      if (!isClosed) error.value = TextosApp.errorSqlite;
    }
  }

  Future<void> sincronizar() async {
    await sincronizacion?.sincronizar();
    if (!isClosed) await cargar();
  }

  /// Abre el formulario con el tipo de ruta de GetX y recarga SQLite al regresar.
  Future<void> nuevo() async {
    await Get.toNamed(Rutas.nuevoTicket);
    if (!isClosed) await cargar();
  }

  /// Abre por Id local y refresca SQLite al volver sin sincronizar ni perder filtros.
  Future<void> abrirDetalle(int idLocal) async {
    await Get.toNamed<void>(Rutas.detalleTicket, arguments: idLocal);
    if (!isClosed) await cargar();
  }

  String nombreSucursal(int id) =>
      catalogo.firstWhereOrNull((s) => s.id == id)?.nombre ??
      TextosApp.sucursal;

  /// Logout preserva filas locales y autoría; el ciclo remoto se corta al cambiar sesión.
  Future<void> cerrarSesion() async {
    if (_cerrando) return;
    _cerrando = true;
    try {
      if (await _sesion.limpiar()) {
        if (!isClosed) Get.offAllNamed<void>(Rutas.login);
      } else if (!isClosed) {
        Get.snackbar(TextosApp.cerrarSesion, TextosApp.errorSesion);
      }
    } finally {
      _cerrando = false;
    }
  }

  @override
  void onClose() {
    _red?.dispose();
    _estadoSync?.dispose();
    super.onClose();
  }
}
