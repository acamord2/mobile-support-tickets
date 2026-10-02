using System.ComponentModel.DataAnnotations;
namespace Tickets.Api.DTOs;
/// <summary>Recibe una creación móvil con clave persistente y fecha independiente; excluye la identidad del técnico porque procede del JWT.</summary>
public sealed class SolicitudTicket
{
    [Range(1, int.MaxValue)] public int BranchId { get; set; }
    [Required, StringLength(200, MinimumLength=1)] public string Title { get; set; } = "";
    [Required, StringLength(10000, MinimumLength=1)] public string Description { get; set; } = "";
    public DateTimeOffset? ScheduledAt { get; set; }
    public Guid ClientRequestId { get; set; }
    public DateTimeOffset? CreatedAt { get; set; }
    public DateTimeOffset? UpdatedAt { get; set; }
}
