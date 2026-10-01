namespace Tickets.Api.DTOs;
/// <summary>Entrega campos públicos de agenda desde la vista SQL; conserva las tres fechas y la clave móvil sin exponer usuarios internos.</summary>
public record RespuestaTicket(int Id, int BranchId, int TechnicianId, string Title, string Description, string Status, DateTime CreatedAt, DateTime UpdatedAt, DateTime ScheduledAt, Guid? ClientRequestId, string BranchName, string BranchAddress);
