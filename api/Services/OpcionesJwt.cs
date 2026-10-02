using System.ComponentModel.DataAnnotations;

namespace Tickets.Api.Services;

/// <summary>Agrupa las opciones JWT enlazadas desde configuración y validadas al iniciar.</summary>
public class OpcionesJwt
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
