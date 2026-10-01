namespace Tickets.Api.DTOs;

/// <summary>
/// Expone únicamente el resultado público de conectividad en un contrato estable.
/// No incluye errores técnicos ni datos de conexión para evitar revelar credenciales.
/// </summary>
/// <param name="Status">Resultado general: ok o error.</param>
/// <param name="Database">Disponibilidad de la base: connected o unavailable.</param>
public record RespuestaSaludBaseDatos(string Status, string Database);
