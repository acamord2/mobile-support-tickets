namespace Tickets.Api.Models;

/// <summary>
/// Mapea la identificación y dirección básicas de una sucursal en Branches.
/// Permite relacionar los tickets con su ubicación sin agregar datos fuera del MVP.
/// </summary>
public class Sucursal
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
}
