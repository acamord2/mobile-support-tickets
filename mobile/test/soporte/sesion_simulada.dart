import 'package:get/get.dart';
import 'package:tikets/modules/home/controlador_inicio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_sesion_local.dart';
import 'package:tikets/app/services/almacenamiento_token.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/models/sesion_local.dart';

/// Simula protección del token en memoria para pruebas sin secretos ni plugins reales.
class TokenSimulado implements AlmacenamientoToken {
  String? valor;
  bool fallar = false;

  /// Lee la clave ficticia sin tocar el almacén seguro del equipo.
  @override
  Future<String?> leer() async => valor;

  /// Permite provocar un fallo para comprobar que no se publica una sesión volátil.
  @override
  Future<void> guardar(String token) async {
    if (fallar) throw StateError('Fallo simulado');
    valor = token;
  }

  /// Retira únicamente la clave ficticia para comprobar logout.
  @override
  Future<void> eliminar() async {
    valor = null;
  }
}

/// Sustituye persistencia en pruebas de widgets para controlar arranque sin canales nativos.
/// Las pruebas del repositorio usan SQLite real; este fake comprueba UI y navegación.
class RepositorioSesionSimulado extends RepositorioSesionLocal {
  SesionLocal? local;

  /// Proporciona infraestructura no abierta porque todas las operaciones se sustituyen.
  RepositorioSesionSimulado()
    : super(
        OperacionesSqlite(ConexionSqlite(fabrica: databaseFactoryFfi)),
        TokenSimulado(),
      ) {
    if (!Get.isRegistered<ControladorInicio>()) {
      Get.lazyPut(
        () => ControladorInicio(Get.find<ServicioSesion>()),
        fenix: true,
      );
    }
  }

  /// Conserva la sesión ficticia entre fachadas para simular reinicio del proceso.
  @override
  Future<void> guardar(SesionLocal sesion) async {
    local = sesion;
  }

  /// Recupera la sesión sin IO para permitir pruebas de rutas deterministas.
  @override
  Future<SesionLocal?> restaurar() async => local;

  /// Retira identidad/token ficticios sin ejecutar SQLite.
  @override
  Future<void> eliminar() async {
    local = null;
  }

  /// El fake de UI no introduce pendientes de negocio.
  @override
  Future<bool> hayPendientes() async => false;

  /// Conserva identidad ficticia sin JWT para reproducir 401 al restaurar la fachada.
  @override
  Future<void> invalidarToken() async {
    final anterior = local;
    if (anterior != null) {
      local = SesionLocal(
        usuario: anterior.usuario,
        autenticadoEn: anterior.autenticadoEn,
        expiraEn: anterior.expiraEn,
      );
    }
  }
}

/// Crea una fachada real con persistencia ficticia para pruebas de consumidores.
ServicioSesion crearSesionSimulada() =>
    ServicioSesion(RepositorioSesionSimulado());
