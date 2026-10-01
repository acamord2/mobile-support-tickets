using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Expone únicamente evidencia de un ticket propio; valida imagen en servidor y mantiene SQL fuera del controller.</summary>
[ApiController, Authorize, Route("api/tickets/{id:int}/evidence")]
public sealed class ControladorCrearEvidencia(AccesoTicketsPostgres datos) : ControllerBase
{
    /// <summary>Comprueba usuario activo y fotografía; reintentos idénticos conservan el Id remoto para no duplicar evidencia por pérdida de respuesta.</summary>
    [HttpPost, RequestSizeLimit(1600000)]
    [ProducesResponseType(200), ProducesResponseType(400), ProducesResponseType(401), ProducesResponseType(404)]
    public async Task<IActionResult> Crear(int id,SolicitudEvidencia solicitud,CancellationToken ct)
    {
        var usuario=IdentidadTecnico.Obtener(User);
        if(usuario==0 || !await datos.Activo(usuario,ct)) return Unauthorized();
        if(!ValidacionEvidencia.Valida(solicitud)) return BadRequest();
        var evidencia=await datos.Evidencia(usuario,id,solicitud,ct);
        return evidencia is null ? NotFound() : Ok(new { id=evidencia.Value });
    }
}
