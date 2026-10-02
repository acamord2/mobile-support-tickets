import 'package:get/get.dart';
import 'cliente_api.dart';
import 'i_conexion_api.dart';
import 'respuesta_api.dart';

/// Implementa el canal de nuestra API por composición con ClienteApi.
class Conexion extends GetxController implements IConexionApi {
  final ClienteApi _client;

  Conexion(this._client);

  /// Delega GET con ruta y token al cliente para conservar su respuesta común.
  @override
  Future<RespuestaApi> get(String route, {String? token}) =>
      _client.get(route, token: token);

  /// Delega POST y su payload JSON sin reinterpretar el resultado del cliente.
  @override
  Future<RespuestaApi> post(String route, {String? token, Object? payload}) =>
      _client.post(route, token: token, payload: payload);

  /// Delega PUT con todos sus argumentos para preservar el contrato existente.
  @override
  Future<RespuestaApi> put(String route, {String? token, Object? payload}) =>
      _client.put(route, token: token, payload: payload);

  /// Delega PATCH al cliente sin transformar payload, token ni respuesta.
  @override
  Future<RespuestaApi> patch(String route, {String? token, Object? payload}) =>
      _client.patch(route, token: token, payload: payload);

  /// Delega DELETE sin cuerpo y conserva el resultado, incluido HTTP 204.
  @override
  Future<RespuestaApi> delete(String route, {String? token}) =>
      _client.delete(route, token: token);

  /// Cierra el cliente que pertenece a esta conexión al finalizar su uso.
  @override
  void close() => _client.close();

  /// Libera el cliente cuando GetX elimina esta dependencia de su registro.
  @override
  void onClose() {
    close();
    super.onClose();
  }
}
