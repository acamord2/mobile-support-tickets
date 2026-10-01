import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tikets/app/constants/app_texts.dart';
import 'package:tikets/app/network/api_client.dart';
import 'package:tikets/app/network/api_routes.dart';
import 'package:tikets/app/network/api_status.dart';

/// Verifica transporte, headers, JSON y fallos con clientes HTTP controlados.
/// Simula respuestas y errores para probar el contrato reutilizable sin depender
/// de PostgreSQL, red o pantallas; cada caso libera el transporte utilizado.
void main() {
  test('GET anónimo construye URL y decodifica health', () async {
    final client = ApiClient(
      baseUrl: 'http://api.example.test:5263',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, ApiRoutes.healthDatabase);
        expect(request.url.host, 'api.example.test');
        expect(request.headers['accept'], 'application/json');
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(
          '{"status":"ok","database":"connected"}',
          ApiStatus.ok,
        );
      }),
    );
    addTearDown(client.close);
    final response = await client.get(ApiRoutes.healthDatabase);
    expect(response.success, isTrue);
    expect(response.statusCode, ApiStatus.ok);
    expect(response.data, {'status': 'ok', 'database': 'connected'});
  });

  for (final method in ['POST', 'PUT', 'PATCH']) {
    test('$method serializa JSON UTF-8 y agrega Bearer', () async {
      final payload = {'description': 'Revisión técnica'};
      final client = ApiClient(
        client: MockClient((request) async {
          expect(request.method, method);
          expect(request.headers['authorization'], 'Bearer token-prueba');
          expect(request.headers['content-type'], contains('application/json'));
          expect(jsonDecode(utf8.decode(request.bodyBytes)), payload);
          return http.Response('{}', ApiStatus.created);
        }),
      );
      addTearDown(client.close);
      final response = switch (method) {
        'POST' => await client.post(
          ApiRoutes.healthDatabase,
          token: 'token-prueba',
          payload: payload,
        ),
        'PUT' => await client.put(
          ApiRoutes.healthDatabase,
          token: 'token-prueba',
          payload: payload,
        ),
        _ => await client.patch(
          ApiRoutes.healthDatabase,
          token: 'token-prueba',
          payload: payload,
        ),
      };
      expect(response.success, isTrue);
      expect(response.statusCode, ApiStatus.created);
    });
  }

  test('DELETE con Bearer acepta 204 sin cuerpo', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.headers['authorization'], 'Bearer token-prueba');
        expect(request.body, isEmpty);
        return http.Response('', ApiStatus.noContent);
      }),
    );
    addTearDown(client.close);
    final response = await client.delete(
      ApiRoutes.healthDatabase,
      token: 'token-prueba',
    );
    expect(response.success, isTrue);
    expect(response.statusCode, ApiStatus.noContent);
    expect(response.data, isNull);
  });

  test('Token vacío no envía Authorization', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response('{}', ApiStatus.ok);
      }),
    );
    addTearDown(client.close);
    expect(
      (await client.get(ApiRoutes.healthDatabase, token: '  ')).success,
      isTrue,
    );
  });

  test('Error HTTP conserva código y título ProblemDetails UTF-8', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('{"title":"Acceso inválido"}'),
          ApiStatus.unauthorized,
        ),
      ),
    );
    addTearDown(client.close);
    final response = await client.get(ApiRoutes.healthDatabase);
    expect(response.success, isFalse);
    expect(response.statusCode, ApiStatus.unauthorized);
    expect(response.message, 'Acceso inválido');
    expect(response.data, {'title': 'Acceso inválido'});
  });

  test(
    '503 JSON sin mensaje produce error explícito y conserva datos',
    () async {
      final client = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            '{"status":"error","database":"unavailable"}',
            ApiStatus.serviceUnavailable,
          ),
        ),
      );
      addTearDown(client.close);
      final response = await client.get(ApiRoutes.healthDatabase);
      expect(response.success, isFalse);
      expect(response.statusCode, ApiStatus.serviceUnavailable);
      expect(response.message, AppTexts.requestFailed);
      expect(response.data, {'status': 'error', 'database': 'unavailable'});
    },
  );

  test('Respuesta 200 no JSON no se presenta como éxito', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response('<html>Error</html>', ApiStatus.ok),
      ),
    );
    addTearDown(client.close);
    final response = await client.get(ApiRoutes.healthDatabase);
    expect(response.success, isFalse);
    expect(response.statusCode, ApiStatus.ok);
    expect(response.message, AppTexts.invalidResponse);
  });

  test('Timeout no inventa un código HTTP', () async {
    final pending = Completer<http.Response>();
    final client = ApiClient(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) => pending.future),
    );
    addTearDown(client.close);
    final response = await client.get(ApiRoutes.healthDatabase);
    pending.complete(http.Response('{}', ApiStatus.ok));
    expect(response.success, isFalse);
    expect(response.statusCode, isNull);
    expect(response.message, AppTexts.requestTimeout);
  });

  test(
    'API inaccesible produce resultado de comunicación controlado',
    () async {
      final client = ApiClient(
        client: MockClient(
          (_) async => throw http.ClientException('Sin conexión'),
        ),
      );
      addTearDown(client.close);
      final response = await client.get(ApiRoutes.healthDatabase);
      expect(response.success, isFalse);
      expect(response.statusCode, isNull);
      expect(response.message, AppTexts.apiUnavailable);
    },
  );

  test('Error inesperado no filtra el detalle técnico', () async {
    final client = ApiClient(
      client: MockClient((_) async => throw StateError('detalle interno')),
    );
    addTearDown(client.close);
    final response = await client.get(ApiRoutes.healthDatabase);
    expect(response.success, isFalse);
    expect(response.statusCode, isNull);
    expect(response.message, AppTexts.communicationError);
  });
}
