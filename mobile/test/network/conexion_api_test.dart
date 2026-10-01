import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tikets/app/bindings/dependencias_app.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/i_conexion_api.dart';
import 'package:tikets/app/network/rutas_api.dart';
import 'package:tikets/app/network/estado_api.dart';
import 'package:tikets/app/network/conexion.dart';

/// Prueba el canal mediante su contrato y el registro GetX sin acceder a la red.
/// Verifica delegación de verbos, argumentos y respuestas para detectar cambios
/// que acoplen los futuros servicios al transporte o rompan la composición.
void main() {
  tearDown(Get.reset);
  test('El contrato delega verbos, JSON y Bearer al cliente', () async {
    final requests = <http.Request>[];
    final IConexionApi connection = Conexion(
      ClienteApi(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"status":"ok"}', EstadoApi.ok);
        }),
      ),
    );
    addTearDown(connection.close);
    final responses = [
      await connection.get(RutasApi.healthDatabase, token: 'token'),
      await connection.post(
        RutasApi.login,
        token: 'token',
        payload: {'value': 1},
      ),
      await connection.put(RutasApi.me, token: 'token', payload: {'value': 1}),
      await connection.patch(
        RutasApi.me,
        token: 'token',
        payload: {'value': 1},
      ),
      await connection.delete(RutasApi.me, token: 'token'),
    ];
    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
    ]);
    expect(requests.first.url.path, RutasApi.healthDatabase);
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer token');
    }
    for (final request in requests.skip(1).take(3)) {
      expect(request.body, '{"value":1}');
    }
    for (final response in responses) {
      expect(response.success, isTrue);
      expect(response.statusCode, EstadoApi.ok);
      expect(response.data, {'status': 'ok'});
    }
  });
  test(
    'El binding resuelve el contrato y permite reconstruirlo tras liberarlo',
    () async {
      DependenciasApp().dependencies();
      final first = Get.find<IConexionApi>();
      expect(first, isA<Conexion>());
      expect(Get.find<IConexionApi>(), same(first));
      await Get.delete<IConexionApi>();
      expect((first as Conexion).isClosed, isTrue);
      final second = Get.find<IConexionApi>();
      expect(second, isA<Conexion>());
      expect(second, isNot(same(first)));
      await Get.delete<IConexionApi>();
    },
  );
}
