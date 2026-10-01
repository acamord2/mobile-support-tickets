import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/textos_app.dart';
import 'configuracion_api.dart';
import 'respuesta_api.dart';
import 'estado_api.dart';

/// Centraliza HTTP, headers, JSON y errores de comunicación en una implementación.
/// Conexion compone este cliente; los futuros servicios usan el contrato
/// IConexionApi para no depender de HTTP. Recibe ruta, payload y token y devuelve
/// RespuestaApi sin incluir lógica de negocio de Login/Tickets.
class ClienteApi {
  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;

  /// Configura un transporte reutilizable con URL y timeout centralizados.
  /// Permite inyectar http.Client para probar contratos sin servidores ni pantallas.
  /// El consumidor debe llamar [close] cuando deje de utilizar esta instancia.
  ClienteApi({
    http.Client? client,
    String baseUrl = ConfiguracionApi.baseUrl,
    Duration timeout = ConfiguracionApi.timeout,
  }) : _client = client ?? http.Client(),
       _baseUrl = Uri.parse(baseUrl),
       _timeout = timeout;

  /// Ejecuta GET sobre la ruta indicada, con Bearer solo cuando se proporciona.
  /// Delega transporte y respuesta al método común para mantener lecturas anónimas
  /// y protegidas con la misma configuración y manejo de errores.
  Future<RespuestaApi> get(String route, {String? token}) =>
      _request('GET', route, token: token);

  /// Ejecuta POST serializando el payload como JSON mediante la operación común.
  /// El consumidor construye los datos y aporta un token opcional, evitando
  /// duplicar configuración HTTP o introducir lógica de negocio en el cliente.
  Future<RespuestaApi> post(String route, {String? token, Object? payload}) =>
      _request('POST', route, token: token, payload: payload);

  /// Ejecuta PUT con JSON y token opcionales mediante el transporte compartido.
  /// Permite enviar actualizaciones completas sin repetir headers ni asumir
  /// qué entidad o endpoint será utilizado posteriormente.
  Future<RespuestaApi> put(String route, {String? token, Object? payload}) =>
      _request('PUT', route, token: token, payload: payload);

  /// Ejecuta PATCH con un payload JSON construido por el consumidor.
  /// Reutiliza el procesamiento HTTP para admitir cambios parciales sin conocer
  /// los campos o reglas de una funcionalidad concreta.
  Future<RespuestaApi> patch(String route, {String? token, Object? payload}) =>
      _request('PATCH', route, token: token, payload: payload);

  /// Ejecuta DELETE sobre una ruta con Bearer opcional y sin cuerpo.
  /// Reutiliza la respuesta común, incluida una respuesta 204 vacía, para mantener
  /// el borrado independiente de los modelos y reglas del consumidor.
  Future<RespuestaApi> delete(String route, {String? token}) =>
      _request('DELETE', route, token: token);

  /// Construye la URL y headers, serializa JSON y convierte fallos en resultados.
  /// Aplica el timeout a envío y lectura completos para evitar esperas indefinidas.
  /// No expone excepciones ni aplica reintentos o sincronización; statusCode null
  /// señala que no hubo una respuesta HTTP disponible.
  Future<RespuestaApi> _request(
    String method,
    String route, {
    String? token,
    Object? payload,
  }) async {
    try {
      final request = http.Request(method, _baseUrl.resolve(route));
      request.headers['Accept'] = 'application/json';
      if (token != null && token.trim().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (payload != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(payload);
      }
      final response = await _send(request).timeout(_timeout);
      return _interpret(response);
    } on TimeoutException {
      return const RespuestaApi(
        success: false,
        message: TextosApp.requestTimeout,
      );
    } on http.ClientException {
      return const RespuestaApi(
        success: false,
        message: TextosApp.apiUnavailable,
      );
    } catch (_) {
      return const RespuestaApi(
        success: false,
        message: TextosApp.communicationError,
      );
    }
  }

  /// Envía la petición y consume su cuerpo antes de completar el Future.
  /// Agrupa ambas esperas para que el timeout del método común también cubra
  /// servidores que entregan headers pero dejan el cuerpo sin terminar.
  Future<http.Response> _send(http.Request request) async {
    final streamed = await _client.send(request);
    return http.Response.fromStream(streamed);
  }

  /// Decodifica JSON UTF-8 y conserva datos/código sin asumir un modelo de negocio.
  /// Acepta cuerpos vacíos y clasifica 2xx como éxito; para errores JSON utiliza
  /// message o title cuando existen. Si el contenido no es JSON devuelve un fallo
  /// explícito, incluso con HTTP 200, para no ocultar una respuesta inválida.
  RespuestaApi _interpret(http.Response response) {
    Object? data;
    if (response.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        return RespuestaApi(
          statusCode: response.statusCode,
          success: false,
          message: TextosApp.invalidResponse,
        );
      }
    }
    final success = EstadoApi.isSuccess(response.statusCode);
    String? message;
    if (data is Map<String, dynamic>) {
      final value = data['message'] ?? data['title'];
      if (value is String) message = value;
    }
    return RespuestaApi(
      statusCode: response.statusCode,
      data: data,
      message: message ?? (success ? null : TextosApp.requestFailed),
      success: success,
    );
  }

  /// Libera las conexiones mantenidas por el transporte HTTP de esta instancia.
  /// También cierra un cliente inyectado; su propietario debe finalizar las
  /// peticiones antes de llamarlo para evitar fugas o uso posterior del transporte.
  void close() => _client.close();
}
