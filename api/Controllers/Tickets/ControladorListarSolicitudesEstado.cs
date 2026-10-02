using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Entrega solicitudes del alcance autenticado, pendientes por defecto y sin datos sensibles.</summary>
[ApiController, Authorize, Route("api/ticket-status-requests")]
public sealed class ControladorListarSolicitudesEstado(AccesoSolicitudesPostgres solicitudes,AccesoTicketsPostgres tickets):ControllerBase
{
    /// <summary>Permite descargar estados revisados para caché local sin ampliar el alcance del rol.</summary>
    [HttpGet]
    [ProducesResponseType<List<RespuestaSolicitudEstado>>(200),ProducesResponseType(401)]
    public async Task<IActionResult> Listar([FromQuery] bool pendingOnly=true,CancellationToken ct=default)
    {
        var usuario=IdentidadTecnico.Obtener(User);
        if (usuario==0 || !await tickets.Activo(usuario,ct)) return Unauthorized();
        return Ok(await solicitudes.Listar(usuario,pendingOnly,ct));
    }
}
