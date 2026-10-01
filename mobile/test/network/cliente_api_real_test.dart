import 'package:flutter_test/flutter_test.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/rutas_api.dart';
import 'package:tikets/app/network/estado_api.dart';

/// Verifica el GET real del cliente contra health sin introducir código de prueba
/// en producción. Se habilita explícitamente con RUN_API_TEST y API_BASE_URL para
/// que las pruebas habituales no dependan de tener la API y PostgreSQL ejecutándose.
void main() {
  const enabled = bool.fromEnvironment('RUN_API_TEST');
  test('ClienteApi conecta con health de la API real', () async {
    final client = ClienteApi();
    addTearDown(client.close);
    final response = await client.get(RutasApi.healthDatabase);
    expect(response.statusCode, EstadoApi.ok, reason: response.message);
    expect(response.success, isTrue);
    expect(response.data, {'status': 'ok', 'database': 'connected'});
  }, skip: !enabled);
}
