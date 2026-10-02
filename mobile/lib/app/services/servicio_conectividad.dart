import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Expone conectividad del dispositivo, no disponibilidad de Internet o API.
class ServicioConectividad extends GetxService with WidgetsBindingObserver {
  final Future<List<ConnectivityResult>> Function() _consultar;
  final Stream<List<ConnectivityResult>> _cambios;
  final redDisponible = Rxn<bool>();
  StreamSubscription<List<ConnectivityResult>>? _suscripcion;
  int _revision = 0;
  bool _cerrado = false;

  ServicioConectividad({
    Future<List<ConnectivityResult>> Function()? consultar,
    Stream<List<ConnectivityResult>>? cambios,
  }) : _consultar = consultar ?? Connectivity().checkConnectivity,
       _cambios = cambios ?? Connectivity().onConnectivityChanged;

  /// Solo considera offline una ausencia de red confirmada por el sistema.
  bool get sinRed => redDisponible.value == false;

  /// Suscribe eventos e inicia una consulta sin bloquear la presentación.
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _suscripcion = _cambios.listen(
      (tipos) {
        _revision++;
        if (!_cerrado) _actualizar(tipos);
      },
      onError: (Object _) {
        _revision++;
        if (!_cerrado) redDisponible.value = null;
      },
    );
    unawaited(refrescar());
  }

  /// Consulta el estado actual sin sobrescribir un evento más reciente.
  Future<void> refrescar() async {
    final revision = ++_revision;
    try {
      final tipos = await _consultar();
      if (!_cerrado && revision == _revision) _actualizar(tipos);
    } catch (_) {
      if (!_cerrado && revision == _revision) redDisponible.value = null;
    }
  }

  /// Reduce los tipos de red a un estado sencillo, incluso con varios transportes.
  void _actualizar(List<ConnectivityResult> tipos) {
    redDisponible.value = tipos.any((tipo) => tipo != ConnectivityResult.none);
  }

  /// Actualiza al regresar a primer plano porque Android limita eventos en fondo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refrescar());
  }

  /// Cancela suscripción y observador para impedir eventos después del cierre.
  @override
  void onClose() {
    _cerrado = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_suscripcion?.cancel());
    super.onClose();
  }
}
