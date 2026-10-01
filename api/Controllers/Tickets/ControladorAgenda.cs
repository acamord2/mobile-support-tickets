using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Expone solo el listado autenticado de agenda; delega PostgreSQL al acceso de datos para mantener el controller sin SQL.</summary>
[ApiController, Authorize, Route("api/tickets")]
public sealed class ControladorAgenda(AccesoTicketsPostgres datos) : ControllerBase
{
    /// <summary>Obtiene identidad del JWT, verifica actividad actual y devuelve tickets propios para descargar a SQLite.</summary>
    [HttpGet]
    [ProducesResponseType<List<RespuestaTicket>>(200), ProducesResponseType(401)]
    public async Task<IActionResult> Obtener(CancellationToken ct)
    {
        var usuario=IdentidadTecnico.Obtener(User);
        if(usuario==0 || !await datos.Activo(usuario,ct)) return Unauthorized();
        return Ok(await datos.Agenda(usuario,ct));
    }
}
