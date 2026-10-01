using System.ComponentModel.DataAnnotations;

namespace Tickets.Api.Services;

/// <summary>
/// Agrupa las opciones JWT enlazadas desde configuración y validadas al iniciar.
/// Mantiene clave, emisor, audiencia y duración fuera del código de autenticación
/// para poder cambiarlos mediante configuración sin recompilar la lógica.
/// </summary>
public class JwtOptions
{
    [Required, MinLength(32)]
    public string Key { get; set; } = string.Empty;

    [Required]
    public string Issuer { get; set; } = string.Empty;

    [Required]
    public string Audience { get; set; } = string.Empty;

    [Range(1, 1440)]
    public int ExpirationMinutes { get; set; }
}
