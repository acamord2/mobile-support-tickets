using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Expone solo sucursales autenticadas para poblar SQLite; evita valores ficticios en el formulario móvil.</summary>
[ApiController, Authorize, Route("api/branches")]
public sealed class ControladorSucursales(AccesoTicketsPostgres datos) : ControllerBase
{
    /// <summary>Valida actividad de la identidad autenticada y devuelve información básica real para sincronización.</summary>
    [HttpGet]
    [ProducesResponseType<List<RespuestaSucursal>>(200), ProducesResponseType(401)]
    public async Task<IActionResult> Obtener(CancellationToken ct)
    {
        var usuario=IdentidadTecnico.Obtener(User);
        if(usuario==0 || !await datos.Activo(usuario,ct)) return Unauthorized();
        return Ok(await datos.Sucursales(ct));
    }
}
