import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tikets/app/constants/textos_app.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/rutas_api.dart';
import 'package:tikets/app/network/estado_api.dart';

/// Verifica transporte, headers, JSON y fallos con clientes HTTP controlados.
/// Simula respuestas y errores para probar el contrato reutilizable sin depender
/// de PostgreSQL, red o pantallas; cada caso libera el transporte utilizado.
void main() {
  test('GET anónimo construye URL y decodifica health', () async {
    final client = ClienteApi(
      baseUrl: 'http://api.example.test:5263',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, RutasApi.healthDatabase);
        expect(request.url.host, 'api.example.test');
        expect(request.headers['accept'], 'application/json');
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(
          '{"status":"ok","database":"connected"}',
          EstadoApi.ok,
        );
      }),
    );
    addTearDown(client.close);
    final response = await client.get(RutasApi.healthDatabase);
    expect(response.success, isTrue);
    expect(response.statusCode, EstadoApi.ok);
    expect(response.data, {'status': 'ok', 'database': 'connected'});
  });

  for (final method in ['POST', 'PUT', 'PATCH']) {
    test('$method serializa JSON UTF-8 y agrega Bearer', () async {
      final payload = {'description': 'Revisión técnica'};
      final client = ClienteApi(
        client: MockClient((request) async {
          expect(request.method, method);
          expect(request.headers['authorization'], 'Bearer token-prueba');
          expect(request.headers['content-type'], contains('application/json'));
          expect(jsonDecode(utf8.decode(request.bodyBytes)), payload);
          return http.Response('{}', EstadoApi.created);
        }),
      );
      addTearDown(client.close);
      final response = switch (method) {
        'POST' => await client.post(
          RutasApi.healthDatabase,
          token: 'token-prueba',
          payload: payload,
        ),
        'PUT' => await client.put(
          RutasApi.healthDatabase,
          token: 'token-prueba',
          payload: payload,
        ),
        _ => await client.patch(
          RutasApi.healthDatabase,
          token: 'token-prueba',
          payload: payload,
        ),
      };
      expect(response.success, isTrue);
      expect(response.statusCode, EstadoApi.created);
    });
  }

  test('DELETE con Bearer acepta 204 sin cuerpo', () async {
    final client = ClienteApi(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.headers['authorization'], 'Bearer token-prueba');
        expect(request.body, isEmpty);
        return http.Response('', EstadoApi.noContent);
      }),
    );
    addTearDown(client.close);
    final response = await client.delete(
      RutasApi.healthDatabase,
      token: 'token-prueba',
    );
    expect(response.success, isTrue);
    expect(response.statusCode, EstadoApi.noContent);
    expect(response.data, isNull);
  });

  test('Token vacío no envía Authorization', () async {
    final client = ClienteApi(
      client: MockClient((request) async {
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response('{}', EstadoApi.ok);
      }),
    );
    addTearDown(client.close);
    expect(
      (await client.get(RutasApi.healthDatabase, token: '  ')).success,
      isTrue,
    );
  });

  test('Error HTTP conserva código y título ProblemDetails UTF-8', () async {
    final client = ClienteApi(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('{"title":"Acceso inválido"}'),
          EstadoApi.unauthorized,
        ),
      ),
    );
    addTearDown(client.close);
    final response = await client.get(RutasApi.healthDatabase);
    expect(response.success, isFalse);
    expect(response.statusCode, EstadoApi.unauthorized);
    expect(response.message, 'Acceso inválido');
    expect(response.data, {'title': 'Acceso inválido'});
  });

  test(
    '503 JSON sin mensaje produce error explícito y conserva datos',
    () async {
      final client = ClienteApi(
        client: MockClient(
          (_) async => http.Response(
            '{"status":"error","database":"unavailable"}',
            EstadoApi.serviceUnavailable,
          ),
        ),
      );
      addTearDown(client.close);
      final response = await client.get(RutasApi.healthDatabase);
      expect(response.success, isFalse);
      expect(response.statusCode, EstadoApi.serviceUnavailable);
      expect(response.message, TextosApp.requestFailed);
      expect(response.data, {'status': 'error', 'database': 'unavailable'});
    },
  );

  test('Respuesta 200 no JSON no se presenta como éxito', () async {
    final client = ClienteApi(
      client: MockClient(
        (_) async => http.Response('<html>Error</html>', EstadoApi.ok),
      ),
    );
    addTearDown(client.close);
    final response = await client.get(RutasApi.healthDatabase);
    expect(response.success, isFalse);
    expect(response.statusCode, EstadoApi.ok);
    expect(response.message, TextosApp.invalidResponse);
  });

  test('Timeout no inventa un código HTTP', () async {
    final pending = Completer<http.Response>();
    final client = ClienteApi(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) => pending.future),
    );
    addTearDown(client.close);
    final response = await client.get(RutasApi.healthDatabase);
    pending.complete(http.Response('{}', EstadoApi.ok));
    expect(response.success, isFalse);
    expect(response.statusCode, isNull);
    expect(response.message, TextosApp.requestTimeout);
  });

  test(
    'API inaccesible produce resultado de comunicación controlado',
    () async {
      final client = ClienteApi(
        client: MockClient(
          (_) async => throw http.ClientException('Sin conexión'),
        ),
      );
      addTearDown(client.close);
      final response = await client.get(RutasApi.healthDatabase);
      expect(response.success, isFalse);
      expect(response.statusCode, isNull);
      expect(response.message, TextosApp.apiUnavailable);
    },
  );

  test('Error inesperado no filtra el detalle técnico', () async {
    final client = ClienteApi(
      client: MockClient((_) async => throw StateError('detalle interno')),
    );
    addTearDown(client.close);
    final response = await client.get(RutasApi.healthDatabase);
    expect(response.success, isFalse);
    expect(response.statusCode, isNull);
    expect(response.message, TextosApp.communicationError);
  });
}
