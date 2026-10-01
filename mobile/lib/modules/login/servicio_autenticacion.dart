import '../../app/constants/textos_app.dart';
import '../../app/network/estado_api.dart';
import '../../app/network/i_conexion_api.dart';
import '../../app/network/rutas_api.dart';
import '../../models/resultado_autenticacion.dart';
import '../../models/sesion_usuario.dart';
import '../../app/services/servicio_conectividad.dart';

/// Autentica mediante el contrato de conexión y convierte JSON a modelos simples.
/// Concentra payload y status del login para que controllers y vistas no conozcan
/// HTTP, URLs, JSON o excepciones técnicas; no guarda credenciales ni sesiones.
class ServicioAutenticacion {
  final IConexionApi _conexion;
  final ServicioConectividad? _conectividad;

  /// Recibe el canal desde DI para reutilizar infraestructura y probarlo sin red.
  /// No crea transportes dentro del servicio ni acopla autenticación a http.
  ServicioAutenticacion(this._conexion, {ServicioConectividad? conectividad})
    : _conectividad = conectividad;

  /// Envía el contrato username/password a la ruta central y valida la respuesta.
  /// Solo 200 con sesión válida resulta exitoso; los demás estados se traducen
  /// a mensajes en español sin mostrar cuerpos, JWT o excepciones al consumidor.
  Future<ResultadoAutenticacion> iniciarSesion(
    String usuario,
    String password,
  ) async {
    if (_conectividad?.sinRed == true) {
      return const ResultadoAutenticacion(
        mensaje: TextosApp.loginRequiereConexion,
      );
    }
    try {
      final respuesta = await _conexion.post(
        RutasApi.login,
        payload: {'username': usuario, 'password': password},
      );
      if (respuesta.statusCode == EstadoApi.ok) {
        final datos = respuesta.data;
        if (!respuesta.success || datos is! Map<String, dynamic>) {
          return const ResultadoAutenticacion(
            mensaje: TextosApp.respuestaLoginInvalida,
          );
        }
        return ResultadoAutenticacion(sesion: SesionUsuario.fromJson(datos));
      }
      final mensaje = switch (respuesta.statusCode) {
        EstadoApi.badRequest => TextosApp.datosLoginInvalidos,
        EstadoApi.unauthorized => TextosApp.credencialesIncorrectas,
        EstadoApi.internalServerError ||
        EstadoApi.serviceUnavailable => TextosApp.errorServidor,
        null => TextosApp.errorConexionLogin,
        _ => TextosApp.errorLogin,
      };
      return ResultadoAutenticacion(mensaje: mensaje);
    } on FormatException {
      return const ResultadoAutenticacion(
        mensaje: TextosApp.respuestaLoginInvalida,
      );
    } catch (_) {
      return const ResultadoAutenticacion(
        mensaje: TextosApp.errorConexionLogin,
      );
    }
  }
}
