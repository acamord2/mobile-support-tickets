import 'usuario.dart';

/// Agrupa identidad autenticada previamente y fechas públicas para restaurar offline.
/// El token opcional proviene del almacén seguro, nunca de SQLite.
class SesionLocal {
  final Usuario usuario;
  final String? token;
  final DateTime autenticadoEn;
  final DateTime? expiraEn;

  /// Conserva identidad aunque falte o expire JWT; la API autoriza lo remoto.
  const SesionLocal({
    required this.usuario,
    required this.autenticadoEn,
    this.token,
    this.expiraEn,
  });
}
