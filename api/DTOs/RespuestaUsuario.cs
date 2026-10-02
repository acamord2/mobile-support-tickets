namespace Tickets.Api.DTOs;

/// <summary>Expone identidad y rol públicos; excluye PasswordHash.</summary>
/// <param name="Id">Identificador consistente con Users y TechnicianId.</param>
/// <param name="Username">Nombre de usuario público.</param>
/// <param name="Name">Nombre mostrado al técnico.</param>
public record RespuestaUsuario(int Id, string Username, string Name, int RoleId, string Role);
