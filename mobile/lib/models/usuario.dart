/// Convierte JSON validando sus tipos para evitar propagar maps o datos internos de autenticación hacia controllers y vistas.
class Usuario {
  final int id;
  final int? roleId;
  final String? role;
  final String username;
  final String name;

  const Usuario({
    required this.id,
    required this.username,
    required this.name,
    this.roleId,
    this.role,
  });

  /// Lee y valida los campos públicos del JSON sin incluirlo en errores.
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
    return Usuario(
      id: id,
      username: username,
      name: name,
      roleId: json['roleId'] as int?,
      role: json['role'] as String?,
    );
  }
}
