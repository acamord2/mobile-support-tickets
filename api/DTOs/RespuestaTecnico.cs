namespace Tickets.Api.DTOs;
/// <summary>Representa identidad pública de un técnico autorizado y relación aplicable, sin credenciales.</summary>
public record RespuestaTecnico(int Id, string Name, int? CoordinatorUserId);
