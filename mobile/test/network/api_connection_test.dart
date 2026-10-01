import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tikets/app/bindings/app_bindings.dart';
import 'package:tikets/app/network/api_client.dart';
import 'package:tikets/app/network/api_connection.dart';
import 'package:tikets/app/network/api_routes.dart';
import 'package:tikets/app/network/api_status.dart';
import 'package:tikets/app/network/conexion.dart';

/// Prueba el canal mediante su contrato y el registro GetX sin acceder a la red.
/// Verifica delegación de verbos, argumentos y respuestas para detectar cambios
/// que acoplen los futuros servicios al transporte o rompan la composición.
void main() {
  tearDown(Get.reset);
  test('El contrato delega verbos, JSON y Bearer al cliente', () async {
    final requests = <http.Request>[];
    final ApiConnection connection = Conexion(
      ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"status":"ok"}', ApiStatus.ok);
        }),
      ),
    );
    addTearDown(connection.close);
    final responses = [
      await connection.get(ApiRoutes.healthDatabase, token: 'token'),
      await connection.post(
        ApiRoutes.login,
        token: 'token',
        payload: {'value': 1},
      ),
      await connection.put(ApiRoutes.me, token: 'token', payload: {'value': 1}),
      await connection.patch(
        ApiRoutes.me,
        token: 'token',
        payload: {'value': 1},
      ),
      await connection.delete(ApiRoutes.me, token: 'token'),
    ];
    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
    ]);
    expect(requests.first.url.path, ApiRoutes.healthDatabase);
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer token');
    }
    for (final request in requests.skip(1).take(3)) {
      expect(request.body, '{"value":1}');
    }
    for (final response in responses) {
      expect(response.success, isTrue);
      expect(response.statusCode, ApiStatus.ok);
      expect(response.data, {'status': 'ok'});
    }
  });
  test(
    'El binding resuelve el contrato y permite reconstruirlo tras liberarlo',
    () async {
      AppBindings().dependencies();
      final first = Get.find<ApiConnection>();
      expect(first, isA<Conexion>());
      expect(Get.find<ApiConnection>(), same(first));
      await Get.delete<ApiConnection>();
      expect((first as Conexion).isClosed, isTrue);
      final second = Get.find<ApiConnection>();
      expect(second, isA<Conexion>());
      expect(second, isNot(same(first)));
      await Get.delete<ApiConnection>();
    },
  );
}
