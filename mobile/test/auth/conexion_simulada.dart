import 'package:tikets/app/network/i_conexion_api.dart';
import 'package:tikets/app/network/respuesta_api.dart';

/// Simula únicamente POST de login y registra el contrato recibido sin usar red.
/// Permite decidir respuestas o esperas desde el test para probar errores y carga
/// sin depender de PostgreSQL ni incluir credenciales demo en la suite habitual.
class ConexionSimulada implements IConexionApi {
  final Future<RespuestaApi> Function() responder;
  int peticiones = 0;
  String? ruta;
  Object? payload;
  String? tokenRecibido;

  /// Recibe la respuesta controlada por el test para aislar el servicio de HTTP.
  /// Puede devolver un Future pendiente para comprobar envíos simultáneos.
  ConexionSimulada(this.responder);

  /// Registra POST y sus argumentos antes de devolver la respuesta simulada.
  /// Detecta payload/rutas incorrectos sin hacer llamadas a la API real.
  @override
  Future<RespuestaApi> post(String route, {String? token, Object? payload}) {
    peticiones++;
    ruta = route;
    this.payload = payload;
    tokenRecibido = token;
    return responder();
  }

  /// Rechaza GET porque estos tests solo permiten el endpoint de autenticación.
  /// Hace visible un cambio accidental de verbo sin simular rutas no requeridas.
  @override
  Future<RespuestaApi> get(String route, {String? token}) =>
      throw UnsupportedError('GET no simulado.');

  /// Rechaza PUT para detectar operaciones fuera del flujo de login de esta prueba.
  /// No necesita otro comportamiento al probar un servicio que solo hace POST.
  @override
  Future<RespuestaApi> put(String route, {String? token, Object? payload}) =>
      throw UnsupportedError('PUT no simulado.');

  /// Rechaza PATCH para no ocultar un verbo inesperado bajo una respuesta válida.
  /// Mantiene el fake limitado a la responsabilidad del servicio de autenticación.
  @override
  Future<RespuestaApi> patch(String route, {String? token, Object? payload}) =>
      throw UnsupportedError('PATCH no simulado.');

  /// Rechaza DELETE porque el logout de esta etapa es solo local y no HTTP.
  /// Evita aprobar por accidente un endpoint no solicitado.
  @override
  Future<RespuestaApi> delete(String route, {String? token}) =>
      throw UnsupportedError('DELETE no simulado.');

  /// No requiere liberar transporte porque el fake no abre conexiones.
  /// Conserva el contrato común para poder sustituir al canal real en tests.
  @override
  void close() {}
}
