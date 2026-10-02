namespace Tickets.Api.Models;

/// <summary>Solo define la estructura aprobada; no selecciona, almacena ni sincroniza imágenes.</summary>
public class Evidencia
{
    public int Id { get; set; }
    public int TicketId { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? PhotoPath { get; set; }
    public string? PhotoBase64 { get; set; }
    public DateTime CreatedAt { get; set; }
}
