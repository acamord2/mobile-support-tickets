import 'dart:convert';
import 'package:get/get.dart';
import '../database/repositorio_sesion_local.dart';
import '../../models/sesion_local.dart';
import '../../models/sesion_usuario.dart';
import '../../models/usuario.dart';

/// Fachada única de identidad local y acceso remoto con persistencia separada.
/// Mantiene Home offline aunque expire JWT y no expone errores técnicos ni secretos.
class ServicioSesion extends GetxService {
  final RepositorioSesionLocal _repositorio;
  SesionLocal? _sesion;
  bool _invalidado = false;
  bool pendientesAlCerrar = false;

  /// Recibe persistencia independiente para evitar SQL y plugins en los consumidores.
  ServicioSesion(this._repositorio);

  /// Expone únicamente identidad pública para representar Home sin API.
  Usuario? get usuario => _sesion?.usuario;

  /// Reconoce identidad previamente autenticada sin exigir JWT vigente.
  bool get existeSesion => usuario != null;

  /// Distingue identidad local de autorización sin expulsar al usuario offline.
  /// exp solo orienta al cliente; la firma y autorización las valida la API.
  bool get requiereReautenticacion =>
      existeSesion &&
      (_invalidado ||
          _sesion!.token == null ||
          _sesion!.expiraEn == null ||
          !_sesion!.expiraEn!.isAfter(DateTime.now().toUtc()));

  /// Entrega JWT solo cuando puede intentarse acceso protegido; aún debe manejarse 401.
  String? get token => requiereReautenticacion ? null : _sesion?.token;

  /// Persiste antes de publicar identidad para impedir login exitoso solo en memoria.
  /// Lee únicamente exp y nunca guarda contraseña ni usa claims como identidad.
  Future<bool> establecer(SesionUsuario sesion) async {
    final local = SesionLocal(
      usuario: sesion.usuario,
      token: sesion.token,
      autenticadoEn: DateTime.now().toUtc(),
      expiraEn: _expiracion(sesion.token),
    );
    try {
      await _repositorio.guardar(local);
      _sesion = local;
      _invalidado = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restaura almacenamiento local antes de elegir ruta, sin requerir Internet.
  /// Un fallo controlado permite reintentar sin inventar identidad ni borrar datos.
  Future<bool> restaurar() async {
    try {
      _sesion = await _repositorio.restaurar();
      _invalidado = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Comprueba pendientes y elimina identidad/token preservando SQLite y la cola.
  /// Limpia memoria después de persistencia; si falla permite reintentar la salida.
  Future<bool> limpiar() async {
    try {
      pendientesAlCerrar = await _repositorio.hayPendientes();
      await _repositorio.eliminar();
      _sesion = null;
      _invalidado = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Prepara 401 retirando JWT sin cerrar Home ni borrar operaciones offline.
  /// Bloquea acceso remoto en memoria incluso si falla el borrado protegido.
  Future<bool> marcarReautenticacion() async {
    _invalidado = true;
    try {
      await _repositorio.invalidarToken();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Interpreta solo caducidad sin validar firma local ni confiar en otros claims.
  /// Formatos desconocidos requieren acceso remoto nuevo pero conservan Home local.
  static DateTime? _expiracion(String token) {
    try {
      final partes = token.split('.');
      if (partes.length != 3) return null;
      final datos = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
      );
      final exp = datos is Map ? datos['exp'] : null;
      return exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
          : null;
    } catch (_) {
      return null;
    }
  }
}
