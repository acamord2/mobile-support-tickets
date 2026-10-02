namespace Tickets.Api.DTOs;
/// <summary>Entrega únicamente identidad y seguimiento públicos de la solicitud, incluyendo solicitante y revisor.</summary>
public record RespuestaSolicitudEstado(int Id, int TicketId, int RequesterUserId, string RequesterName,
    string Type, string? Reason, string Status, DateTime CreatedAt, int? ReviewedByUserId,
    string? ReviewerName, DateTime? ReviewedAt, Guid ClientRequestId, string TicketTitle);
