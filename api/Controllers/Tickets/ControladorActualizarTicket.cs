using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;
/// <summary>Expone solo actualización de ticket propio; separa el endpoint y delega persistencia parametrizada sin SQL en presentación HTTP.</summary>
[ApiController, Authorize, Route("api/tickets/{id:int}")]
public sealed class ControladorActualizarTicket(AccesoTicketsPostgres datos) : ControllerBase
{
    /// <summary>Valida estados simples y aplica cambios sin alterar Id, clave cliente, técnico ni fecha de creación.</summary>
    [HttpPut]
    [ProducesResponseType(200), ProducesResponseType(400), ProducesResponseType(401), ProducesResponseType(404)]
    public async Task<IActionResult> Actualizar(int id, SolicitudActualizarTicket solicitud, CancellationToken ct)
    {
        var usuario = IdentidadTecnico.Obtener(User);
        if (usuario == 0 || !await datos.Activo(usuario, ct)) return Unauthorized();
        if (await datos.Rol(usuario, ct) is not (1 or 2 or 3)) return Forbid();
        if (solicitud.Status is not ("Pending" or "InProgress" or "Resolved" or "Cancelled") || string.IsNullOrWhiteSpace(solicitud.Title) || string.IsNullOrWhiteSpace(solicitud.Description)) return BadRequest();
        return await datos.Actualizar(usuario, id, solicitud, ct) ? Ok(new { id }) : NotFound();
    }
}
