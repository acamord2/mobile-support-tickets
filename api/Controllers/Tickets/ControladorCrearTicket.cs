using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Expone solo la creación idempotente autenticada; valida el contrato y delega la garantía concurrente al acceso a datos.</summary>
[ApiController, Authorize, Route("api/tickets")]
public sealed class ControladorCrearTicket(AccesoTicketsPostgres datos) : ControllerBase
{
    /// <summary>Devuelve el mismo ticket para la misma clave y técnico; no admite identidad arbitraria en el payload.</summary>
    [HttpPost]
    [ProducesResponseType<RespuestaTicket>(200), ProducesResponseType(400), ProducesResponseType(401)]
    public async Task<IActionResult> Crear(SolicitudTicket solicitud,CancellationToken ct)
    {
        var usuario=IdentidadTecnico.Obtener(User);
        if(usuario==0 || !await datos.Activo(usuario,ct)) return Unauthorized();
        if(solicitud.ClientRequestId==Guid.Empty || solicitud.ScheduledAt==default || string.IsNullOrWhiteSpace(solicitud.Title) || string.IsNullOrWhiteSpace(solicitud.Description)) return BadRequest();
        if(solicitud.CreatedAt is not null && solicitud.UpdatedAt is not null && solicitud.UpdatedAt < solicitud.CreatedAt) return BadRequest();
        var ticket=await datos.Crear(usuario,solicitud,ct);
        return ticket is null ? BadRequest() : Ok(ticket);
    }
}
