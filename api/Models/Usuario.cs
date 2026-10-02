namespace Tickets.Api.Models;

/// <summary>Representa un usuario de la tabla Users con un hash de contraseña estándar.</summary>
public class Usuario
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int RoleId { get; set; }
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string Role { get; set; } = string.Empty;
    public short IsActive { get; set; }
}
