using System.ComponentModel.DataAnnotations;
namespace Tickets.Api.DTOs;
/// <summary>Recibe fotografía JPEG completa sin prefijo y descripción; el servicio valida contenido y bytes decodificados antes de guardar.</summary>
public sealed class SolicitudEvidencia
{
    [Required, StringLength(10000)] public string Description { get; set; } = "";
    public string? PhotoBase64 { get; set; }
    public string? Mime { get; set; }
}
