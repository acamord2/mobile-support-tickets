using Tickets.Api.Models;
namespace Tickets.Api.DTOs;
/// <summary>Transporta una decisión offline y claves de sus eventos; no permite elegir al revisor.</summary>
public sealed class RevisionSolicitudEstado
{
    public string Status { get; set; } = "";
    public DateTimeOffset ReviewedAt { get; set; }
    public Guid DecisionClientRequestId { get; set; }
    public Guid? FinalClientRequestId { get; set; }
    /// <summary>Exige identidad del evento final solo al aprobar para garantizar reintentos coherentes.</summary>
    public bool EsValida() => Status is TipoSolicitudEstado.Aprobada or TipoSolicitudEstado.Rechazada
        && ReviewedAt != default && DecisionClientRequestId != Guid.Empty
        && (Status != TipoSolicitudEstado.Aprobada || FinalClientRequestId is not null && FinalClientRequestId != Guid.Empty && FinalClientRequestId != DecisionClientRequestId);
}
