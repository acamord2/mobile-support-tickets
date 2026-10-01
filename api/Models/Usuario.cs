namespace Tickets.Api.Models;

/// <summary>
/// Representa un usuario de la tabla Users con un hash de contraseña estándar.
/// Es un modelo interno de persistencia; los endpoints utilizan DTOs públicos
/// para impedir que PasswordHash se incluya en las respuestas.
/// </summary>
public class Usuario
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}
