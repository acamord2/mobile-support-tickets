namespace Tickets.Api.DTOs;

/// <summary>Entrega descripción, fecha y fotografía existentes para consulta offline; omite información privada de autenticación.</summary>
public record RespuestaEvidencia(int Id, string Description, string? PhotoBase64, DateTime CreatedAt);
