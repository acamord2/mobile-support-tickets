using System.ComponentModel.DataAnnotations;

namespace Tickets.Api.DTOs;

/// <summary>
/// Limita las credenciales de entrada sin permitir modificar el hash almacenado.
/// </summary>
public class SolicitudLogin
{
    [Required, StringLength(100)]
    public string Username { get; set; } = string.Empty;

    [Required, StringLength(1024)]
    public string Password { get; set; } = string.Empty;
}
