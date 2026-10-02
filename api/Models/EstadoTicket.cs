namespace Tickets.Api.Models;

/// <summary>Define los únicos estados aprobados del MVP y sus nombres persistidos como texto.</summary>
public enum EstadoTicket
{
    Pending,
    InProgress,
    Resolved,
    Cancelled
}
