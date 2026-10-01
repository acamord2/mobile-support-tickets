namespace Tickets.Api.DTOs;
/// <summary>Representa únicamente la sucursal disponible para formularios locales, sin añadir campos al contrato aprobado.</summary>
public record RespuestaSucursal(int Id, string Name, string Address);
