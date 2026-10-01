using Tickets.Api.Models;
namespace Tickets.Api.DTOs;

/// <summary>Entrega autor público, fecha original y enlace a evidencia; no duplica contenido fotográfico.</summary>
public record RespuestaEvento(int Id, int TicketId, TipoEventoTicket EventType, string Description,
    DateTime CreatedAt, int UserId, string UserName, Guid ClientRequestId,
    DateTime? PreviousScheduledAt, DateTime? ScheduledAt, int? EvidenceId);
