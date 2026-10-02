namespace Tickets.Api.DTOs;

/// <summary>
/// Entrega JWT e identidad pública sin exponer el hash de contraseña.
/// </summary>
/// <param name="Token">JWT emitido para el usuario validado.</param>
/// <param name="User">Información pública del usuario.</param>
public record RespuestaLogin(string Token, RespuestaUsuario User);
