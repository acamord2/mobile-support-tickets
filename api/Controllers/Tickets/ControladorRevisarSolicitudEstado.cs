using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Expone únicamente revisión, separada de creación y restringida a coordinación/administración.</summary>
[ApiController, Authorize, Route("api/ticket-status-requests/{id:int}/review")]
public sealed class ControladorRevisarSolicitudEstado(AccesoSolicitudesPostgres solicitudes,AccesoTicketsPostgres tickets):ControllerBase
{
    /// <summary>Deriva revisor del JWT; los permisos vigentes y el alcance se revalidan dentro de la transacción.</summary>
    [HttpPut]
    [ProducesResponseType(200),ProducesResponseType(400),ProducesResponseType(401),ProducesResponseType(403),ProducesResponseType(409)]
    public async Task<IActionResult> Revisar(int id,RevisionSolicitudEstado s,CancellationToken ct)
    {
        var usuario=IdentidadTecnico.Obtener(User);
        if (usuario==0 || !await tickets.Activo(usuario,ct)) return Unauthorized();
        if (await tickets.Rol(usuario,ct) is not (1 or 3)) return Forbid();
        if (!s.EsValida()) return BadRequest();
        var resultado=await solicitudes.Revisar(usuario,id,s,ct);
        return resultado is null?Conflict(new { error="Solicitud fuera de alcance o decisión incompatible." }):Ok(new { id=resultado.Value });
    }
}
