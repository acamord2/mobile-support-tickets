using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Expone una operación de coordinación con autorización real y acceso SQL separado.</summary>
[ApiController, Authorize, Route("api/tickets/{id:int}/assignment")]
public sealed class ControladorAsignarTicket(AccesoCoordinacionPostgres datos, AccesoTicketsPostgres tickets) : ControllerBase
{
    /// <summary>Comprueba identidad activa y rol antes de delegar la operación dentro de su alcance.</summary>
    [HttpPut]
    [ProducesResponseType(200), ProducesResponseType(401), ProducesResponseType(403)]
    public async Task<IActionResult> Ejecutar(int id, SolicitudAsignacion solicitud, CancellationToken ct)
    {
        var usuario = IdentidadTecnico.Obtener(User);
        if (usuario == 0 || !await tickets.Activo(usuario, ct)) return Unauthorized();
        if (await tickets.Rol(usuario, ct) is not (1 or 3)) return Forbid();
        return await datos.Asignar(usuario, id, solicitud.TechnicianId, ct) ? Ok(new { id }) : Forbid();
    }
}
