import 'package:flutter_test/flutter_test.dart';
import 'package:tikets/app/network/api_client.dart';
import 'package:tikets/app/network/api_routes.dart';
import 'package:tikets/app/network/api_status.dart';

/// Verifica el GET real del cliente contra health sin introducir código de prueba
/// en producción. Se habilita explícitamente con RUN_API_TEST y API_BASE_URL para
/// que las pruebas habituales no dependan de tener la API y PostgreSQL ejecutándose.
void main() {
  const enabled = bool.fromEnvironment('RUN_API_TEST');
  test('ApiClient conecta con health de la API real', () async {
    final client = ApiClient();
    addTearDown(client.close);
    final response = await client.get(ApiRoutes.healthDatabase);
    expect(response.statusCode, ApiStatus.ok, reason: response.message);
    expect(response.success, isTrue);
    expect(response.data, {'status': 'ok', 'database': 'connected'});
  }, skip: !enabled);
}
