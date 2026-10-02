namespace Tickets.Api.DTOs;

/// <summary>Comunica disponibilidad sin revelar errores técnicos ni credenciales.</summary>
/// <param name="Status">Resultado general: ok o error.</param>
/// <param name="Database">Disponibilidad de la base: connected o unavailable.</param>
public record RespuestaSaludBaseDatos(string Status, string Database);
