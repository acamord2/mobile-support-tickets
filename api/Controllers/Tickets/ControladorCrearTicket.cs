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
    /// <summary>Devuelve el mismo ticket por UUID y reportante original, incluso tras reasignación; no admite identidad arbitraria.</summary>
    [HttpPost]
    [ProducesResponseType<RespuestaTicket>(200), ProducesResponseType(400), ProducesResponseType(401)]
    public async Task<IActionResult> Crear(SolicitudTicket solicitud,CancellationToken ct)
    {
        var usuario=IdentidadTecnico.Obtener(User);
        if(usuario==0 || !await datos.Activo(usuario,ct)) return Unauthorized();
        if(await datos.Rol(usuario,ct) is not (1 or 2 or 4)) return Forbid();
        if(solicitud.ClientRequestId==Guid.Empty || string.IsNullOrWhiteSpace(solicitud.Title) || string.IsNullOrWhiteSpace(solicitud.Description)) return BadRequest();
        if(solicitud.CreatedAt is not null && solicitud.UpdatedAt is not null && solicitud.UpdatedAt < solicitud.CreatedAt) return BadRequest();
        if (await datos.Rol(usuario,ct) is 2 or 4 && solicitud.ScheduledAt is not null) return BadRequest();
        var ticket=await datos.Crear(usuario,solicitud,ct);
        return ticket is null ? BadRequest() : Ok(ticket);
    }
}
