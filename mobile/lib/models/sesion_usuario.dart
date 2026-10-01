import 'usuario.dart';

/// Contiene el JWT opaco y la identidad pública de una autenticación válida.
/// Agrupa el resultado JSON en un modelo simple; no persiste ni imprime el token.
class SesionUsuario {
  final String token;
  final Usuario usuario;

  /// Construye una sesión en el servicio de sesión para consumir endpoints protegidos después.
  /// Conserva el token sin interpretarlo porque su validación corresponde a la API.
  const SesionUsuario({required this.token, required this.usuario});

  /// Valida la forma de la respuesta de login y convierte la identidad pública.
  /// No incluye JSON ni token en excepciones para controlar respuestas inesperadas
  /// sin filtrar credenciales a logs, tests o presentación.
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
