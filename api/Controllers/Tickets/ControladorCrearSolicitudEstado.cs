using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Recibe una solicitud de estado, sin resolver ni cancelar directamente el ticket.</summary>
[ApiController, Authorize, Route("api/tickets/{id:int}/status-requests")]
public sealed class ControladorCrearSolicitudEstado(AccesoSolicitudesPostgres solicitudes,AccesoTicketsPostgres tickets):ControllerBase
{
    /// <summary>Valida identidad y contenido; datos revalida pertenencia y conserva evento/solicitud en una transacción.</summary>
    [HttpPost]
    [ProducesResponseType(200),ProducesResponseType(400),ProducesResponseType(401),ProducesResponseType(409)]
    public async Task<IActionResult> Crear(int id,SolicitudEstadoTicket s,CancellationToken ct)
    {
        var usuario=IdentidadTecnico.Obtener(User);
        if (usuario==0 || !await tickets.Activo(usuario,ct)) return Unauthorized();
        if (!s.EsValida()) return BadRequest();
        var resultado=await solicitudes.Crear(usuario,id,s,ct);
        return resultado is null?Conflict(new { error="Solicitud no disponible en este alcance o ya existe una pendiente." }):Ok(new { id=resultado.Value });
    }
}
