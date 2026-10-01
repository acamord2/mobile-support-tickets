using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
namespace Tickets.Api.Controllers.Tickets;

/// <summary>Entrega cronología pública propia para caché SQLite sin consultas desde las vistas.</summary>
[ApiController, Authorize, Route("api/tickets/{id:int}/events")]
public sealed class ControladorListarEventos(AccesoEventosPostgres eventos, AccesoTicketsPostgres tickets) : ControllerBase
{
    /// <summary>Filtra por identidad JWT activa; un ticket ajeno nunca expone eventos.</summary>
    [HttpGet]
    [ProducesResponseType<List<RespuestaEvento>>(200), ProducesResponseType(401)]
    public async Task<IActionResult> Listar(int id, CancellationToken ct)
    {
        var usuario = IdentidadTecnico.Obtener(User);
        if (usuario == 0 || !await tickets.Activo(usuario, ct)) return Unauthorized();
        return Ok(await eventos.Listar(usuario, id, ct));
    }
}
