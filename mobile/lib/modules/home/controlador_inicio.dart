import 'dart:async';
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

/// Coordina agenda exclusivamente local y eventos de sincronización; el servicio
/// escribe SQLite y después se refresca el repositorio, nunca API hacia widgets.
class ControladorInicio extends GetxController {
  final ServicioSesion _sesion;
  final RepositorioTickets? repositorio;
  final RepositorioSucursales? sucursales;
  final ServicioSincronizacion? sincronizacion;
  final ServicioConectividad? conectividad;
  final agenda = <TicketLocal>[].obs;
  final catalogo = <SucursalLocal>[].obs;
  final conteos = <String, int>{
    'Pending': 0,
    'InProgress': 0,
    'Resolved': 0,
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
  String get fechaActual =>
      DateTime.now().toLocal().toString().split(' ').first;

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
      final resumen = await repositorio!.conteos(id);
      if (isClosed || usuario?.id != id) return;
      agenda.assignAll(lista);
      catalogo.assignAll(ramas);
      conteos.assignAll(resumen);
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

  Future<void> nuevo() async {
    await Get.toNamed<bool>(Rutas.nuevoTicket);
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
    super.onClose();
  }
}
