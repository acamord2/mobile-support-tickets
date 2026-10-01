namespace Tickets.Api.Models;

/// <summary>
/// Define los únicos estados aprobados del MVP y sus nombres persistidos como texto.
/// Evita una tabla catálogo o un workflow adicional en la línea base.
/// </summary>
public enum TicketStatus
{
    Pending,
    InProgress,
    Resolved
}
