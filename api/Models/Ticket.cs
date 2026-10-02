namespace Tickets.Api.Models;

/// <summary>Conserva los campos aprobados para preparar persistencia sin implementar todavía endpoints de atención, historial ni sincronización.</summary>
public class Ticket
{
    public int Id { get; set; }
    public int BranchId { get; set; }
    public int? TechnicianId { get; set; }
    public int? ReporterUserId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public EstadoTicket Status { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? ScheduledAt { get; set; }
    public Guid? ClientRequestId { get; set; }
}
