using System.ComponentModel.DataAnnotations;
using Tickets.Api.Models;
namespace Tickets.Api.DTOs;

/// <summary>Recibe la instantánea offline y UUID original, sin permitir elegir autor ni almacenar Base64 en el evento.</summary>
public sealed class SolicitudEvento
{
    [Required] public TipoEventoTicket? EventType { get; set; }
    [StringLength(10000)] public string Description { get; set; } = "";
    [Required] public DateTimeOffset? CreatedAt { get; set; }
    public Guid ClientRequestId { get; set; }
    public DateTimeOffset? PreviousScheduledAt { get; set; }
    public DateTimeOffset? ScheduledAt { get; set; }
    [Range(1, int.MaxValue)] public int? EvidenceId { get; set; }

    /// <summary>Valida tipo, programación y contenido mínimo; el acceso comprueba fotografía real y pertenencia.</summary>
    public bool EsValida() => EventType is not null && Enum.IsDefined(EventType.Value)
        && CreatedAt is not null && ClientRequestId != Guid.Empty && Description is not null
        && (EvidenceId is null || EventType is TipoEventoTicket.SEGUIMIENTO or TipoEventoTicket.CREADO)
        && (!string.IsNullOrWhiteSpace(Description) || (EventType == TipoEventoTicket.SEGUIMIENTO && EvidenceId is not null))
        && (EventType switch
        {
            TipoEventoTicket.PROGRAMADO => PreviousScheduledAt is null && ScheduledAt is not null,
            TipoEventoTicket.REPROGRAMADO => PreviousScheduledAt is not null && ScheduledAt is not null && PreviousScheduledAt != ScheduledAt,
            _ => PreviousScheduledAt is null && ScheduledAt is null
        });
}
