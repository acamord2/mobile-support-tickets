namespace Tickets.Api.DTOs;

/// <summary>
/// Representa únicamente los campos públicos de identidad utilizados por la API.
/// Evita serializar User directamente y exponer PasswordHash por accidente.
/// </summary>
/// <param name="Id">Identificador consistente con Users y TechnicianId.</param>
/// <param name="Username">Nombre de usuario público.</param>
/// <param name="Name">Nombre mostrado al técnico.</param>
public record UserResponse(int Id, string Username, string Name);
