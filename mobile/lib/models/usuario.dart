/// Representa exclusivamente la identidad pública recibida de nuestra API.
/// Convierte JSON validando sus tipos para evitar propagar maps o datos internos
/// de autenticación hacia controllers y vistas.
class Usuario {
  final int id;
  final String username;
  final String name;

  /// Construye una identidad inmutable con los tres campos públicos del contrato.
  /// No incorpora contraseña ni hash porque la presentación solo necesita identidad.
  const Usuario({required this.id, required this.username, required this.name});

  /// Lee y valida los campos públicos del JSON sin incluirlo en errores.
  /// Rechaza respuestas incompletas para que el servicio controle el fallo y no
  /// establezca una sesión con una identidad inválida.
  factory Usuario.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    final name = json['name'];
    if (id is! int ||
        id <= 0 ||
        username is! String ||
        username.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('Identidad pública inválida.');
    }
    return Usuario(id: id, username: username, name: name);
  }
}
