namespace Tickets.Api.DTOs;
/// <summary>Entrega campos públicos de agenda desde la vista SQL; conserva las tres fechas y la clave móvil sin exponer usuarios internos.</summary>
public record RespuestaTicket(int Id, int BranchId, int? TechnicianId, string Title, string Description, string Status, DateTime CreatedAt, DateTime UpdatedAt, DateTime ScheduledAt, Guid? ClientRequestId, string BranchName, string BranchAddress)
{
    /// <summary>Identifica reportante real; NULL conserva historia anterior sin atribuirla al técnico.</summary>
    public int? ReporterUserId { get; init; }
    /// <summary>Incluye seguimiento disponible para almacenarlo localmente durante sincronización, sin consultas HTTP desde las vistas.</summary>
    public List<RespuestaEvidencia> Evidences { get; init; } = [];
}
