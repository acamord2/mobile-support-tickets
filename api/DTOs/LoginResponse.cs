namespace Tickets.Api.DTOs;

/// <summary>
/// Transporta un JWT y la identidad pública, sin exponer la entidad de persistencia.
/// Mantiene explícito el contrato HTTP y evita incluir el hash de contraseña.
/// </summary>
/// <param name="Token">JWT emitido para el usuario validado.</param>
/// <param name="User">Información pública del usuario.</param>
public record LoginResponse(string Token, UserResponse User);
