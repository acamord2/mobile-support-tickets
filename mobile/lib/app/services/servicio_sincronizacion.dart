import 'package:get/get.dart';
import '../database/repositorio_cola.dart';
import '../database/operacion_pendiente.dart';
import '../database/resultado_sqlite.dart';
import '../network/i_conexion_api.dart';
import '../network/estado_api.dart';
import '../network/rutas_api.dart';
import 'servicio_conectividad.dart';
import 'servicio_sesion.dart';

/// Prepara sincronización transversal sin enviar cambios ni anticipar Tickets.
/// Depende de conectividad, canal API, cola local y sesión; la UI de negocio futura
/// leerá SQLite después de las escrituras, nunca registros descargados directamente.
class ServicioSincronizacion extends GetxService {
  final ServicioConectividad _conectividad;
  final IConexionApi _api;
  final RepositorioCola _cola;
  final ServicioSesion _sesion;
  final apiDisponible = Rxn<bool>();

  /// Recibe infraestructura compartida; no crea transportes ni abre la base local.
  /// El token vigente se consultará mediante la fachada al enviar, nunca se incluirá en la cola.
  ServicioSincronizacion(
    this._conectividad,
    this._api,
    this._cola,
    this._sesion,
  );

  /// Expone si existen las condiciones locales mínimas, sin garantizar acceso API.
  /// La comprobación remota debe seguir manejando timeout y errores del transporte.
  bool get puedeIntentarEnvio => !_conectividad.sinRed && _sesion.token != null;

  /// Prepara el tratamiento de respuestas protegidas sin implementar envíos de Tickets.
  /// Un 401 exige nueva autenticación manteniendo identidad, SQLite y pendientes.
  Future<void> registrarEstadoProtegido(int? estado) async {
    if (estado == EstadoApi.unauthorized) await _sesion.marcarReautenticacion();
  }

  /// Lee trabajo local pendiente sin alterarlo ni devolver respuestas de la API.
  /// No inicia envíos hasta definir contratos, autoría y conflictos del recurso.
  Future<ResultadoSqlite<List<OperacionPendiente>>> consultarPendientes() =>
      _cola.obtenerPendientes();

  /// Comprueba manualmente el health existente, sin JWT ni polling automático.
  /// Guarda solo disponibilidad, no datos remotos; red disponible no implica API sana.
  Future<bool> comprobarDisponibilidadApi() async {
    if (_conectividad.sinRed) return apiDisponible.value = false;
    try {
      final respuesta = await _api.get(RutasApi.healthDatabase);
      final datos = respuesta.data;
      return apiDisponible.value =
          respuesta.success &&
          respuesta.statusCode == EstadoApi.ok &&
          datos is Map &&
          datos['status'] == 'ok' &&
          datos['database'] == 'connected';
    } catch (_) {
      return apiDisponible.value = false;
    }
  }
}
