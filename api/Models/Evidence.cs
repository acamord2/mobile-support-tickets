namespace Tickets.Api.Models;

/// <summary>
/// Mapea la descripción y ruta opcional de una evidencia relacionada con un ticket.
/// Solo define la estructura aprobada; no selecciona, almacena ni sincroniza imágenes.
/// </summary>
public class Evidence
{
    public int Id { get; set; }
    public int TicketId { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? PhotoPath { get; set; }
    public DateTime CreatedAt { get; set; }
}
