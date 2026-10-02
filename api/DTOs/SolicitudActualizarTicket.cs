using System.ComponentModel.DataAnnotations;
namespace Tickets.Api.DTOs;
/// <summary>Recibe cambios locales de un ticket existente sin permitir reasignar técnico, clave ni creación; conserva programación independiente.</summary>
public sealed class SolicitudActualizarTicket
{
    [Required,StringLength(200)] public string Title { get; set; }="";
    [Required,StringLength(10000)] public string Description { get; set; }="";
    [Required] public string Status { get; set; }="Pending";
    public DateTimeOffset? ScheduledAt { get; set; }
}
