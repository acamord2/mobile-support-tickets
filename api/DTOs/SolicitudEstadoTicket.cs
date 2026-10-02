using System.ComponentModel.DataAnnotations;
using Tickets.Api.Models;
namespace Tickets.Api.DTOs;
/// <summary>Recibe tipo, motivo e identidades estables offline; el autor siempre procede de la sesión autenticada.</summary>
public sealed class SolicitudEstadoTicket
{
    [Required] public string Type { get; set; } = "";
    [StringLength(10000)] public string? Reason { get; set; }
    public Guid ClientRequestId { get; set; }
    public Guid EventClientRequestId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    /// <summary>Rechaza motivos vacíos de cancelación y claves inválidas antes de cualquier escritura.</summary>
    public bool EsValida() => Type is TipoSolicitudEstado.Resolucion or TipoSolicitudEstado.Cancelacion
        && (Type != TipoSolicitudEstado.Cancelacion || !string.IsNullOrWhiteSpace(Reason))
        && ClientRequestId != Guid.Empty && EventClientRequestId != Guid.Empty && CreatedAt != default;
}
