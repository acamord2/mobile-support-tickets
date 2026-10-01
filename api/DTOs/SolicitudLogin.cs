using System.ComponentModel.DataAnnotations;

namespace Tickets.Api.DTOs;

/// <summary>
/// Recibe las credenciales del endpoint existente con validación básica de tamaño.
/// Separa la entrada HTTP de Usuario para impedir recibir o modificar el hash de BD.
/// </summary>
public class SolicitudLogin
{
    [Required, StringLength(100)]
    public string Username { get; set; } = string.Empty;

    [Required, StringLength(1024)]
    public string Password { get; set; } = string.Empty;
}
