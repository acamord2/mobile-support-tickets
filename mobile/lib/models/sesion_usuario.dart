import 'usuario.dart';

/// Conserva el JWT opaco y la identidad pública; la API valida el token.
class SesionUsuario {
  final String token;
  final Usuario usuario;

  const SesionUsuario({required this.token, required this.usuario});

  /// Valida el contrato de login sin incluir credenciales en errores.
  factory SesionUsuario.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final usuario = json['user'];
    if (token is! String ||
        token.trim().isEmpty ||
        usuario is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de autenticación inválida.');
    }
    return SesionUsuario(token: token, usuario: Usuario.fromJson(usuario));
  }
}
