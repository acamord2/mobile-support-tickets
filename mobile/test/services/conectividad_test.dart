import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';

/// Comprueba eventos, reanudación y fallos del dispositivo con fuentes simuladas.
/// Distingue red de API y evita consultas externas o cambios de red reales.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);
  test(
    'Red inicial, desconexión, reconexión y cierre de suscripción',
    () async {
      final eventos = StreamController<List<ConnectivityResult>>.broadcast(
        sync: true,
      );
      addTearDown(eventos.close);
      final servicio = Get.put(
        ServicioConectividad(
          consultar: () async => [ConnectivityResult.wifi],
          cambios: eventos.stream,
        ),
      );
      await servicio.refrescar();
      expect(servicio.redDisponible.value, isTrue);
      eventos.add([ConnectivityResult.none]);
      expect(servicio.sinRed, isTrue);
      eventos.add([ConnectivityResult.none, ConnectivityResult.mobile]);
      expect(servicio.sinRed, isFalse);
      await Get.delete<ServicioConectividad>(force: true);
      expect(eventos.hasListener, isFalse);
      eventos.add([ConnectivityResult.none]);
      expect(servicio.redDisponible.value, isTrue);
    },
  );
  test('Evento reciente prevalece sobre consulta inicial tardía', () async {
    final eventos = StreamController<List<ConnectivityResult>>.broadcast(
      sync: true,
    );
    final respuesta = Completer<List<ConnectivityResult>>();
    addTearDown(eventos.close);
    final servicio = Get.put(
      ServicioConectividad(
        consultar: () => respuesta.future,
        cambios: eventos.stream,
      ),
    );
    eventos.add([ConnectivityResult.none]);
    respuesta.complete([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(servicio.sinRed, isTrue);
  });
  test('Refresca al reanudar y un error deja estado desconocido', () async {
    var consultas = 0;
    final servicio = Get.put(
      ServicioConectividad(
        consultar: () async {
          consultas++;
          if (consultas > 1) throw StateError('Fallo simulado');
          return [ConnectivityResult.none];
        },
        cambios: const Stream.empty(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(servicio.sinRed, isTrue);
    servicio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(consultas, 2);
    expect(servicio.redDisponible.value, isNull);
    expect(servicio.sinRed, isFalse);
  });
}
