using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Services;
using Tickets.Api.Models;
namespace Tickets.Api.Controllers.Tickets;

/// <summary>Expone creación idempotente de eventos, con autor derivado del JWT y acceso de datos separado.</summary>
[ApiController, Authorize, Route("api/tickets/{id:int}/events")]
public sealed class ControladorCrearEvento(AccesoEventosPostgres eventos, AccesoTicketsPostgres tickets) : ControllerBase
{
    /// <summary>Valida usuario activo y contrato; no genera eventos duplicados al sincronizar negocio.</summary>
    [HttpPost]
    [ProducesResponseType(200), ProducesResponseType(400), ProducesResponseType(401), ProducesResponseType(404)]
    public async Task<IActionResult> Crear(int id, SolicitudEvento solicitud, CancellationToken ct)
    {
        var usuario = IdentidadTecnico.Obtener(User);
        if (usuario == 0 || !await tickets.Activo(usuario, ct)) return Unauthorized();
        if (!solicitud.EsValida()) return BadRequest();
        var rol = await tickets.Rol(usuario, ct);
        // Solicitudes y decisiones se registran únicamente en su transacción de negocio.
        if (solicitud.EventType is TipoEventoTicket.SOLICITUD_RESOLUCION or TipoEventoTicket.SOLICITUD_CANCELACION
            or TipoEventoTicket.RESOLUCION_APROBADA or TipoEventoTicket.RESOLUCION_RECHAZADA
            or TipoEventoTicket.CANCELACION_APROBADA or TipoEventoTicket.CANCELACION_RECHAZADA
            or TipoEventoTicket.RESUELTO or TipoEventoTicket.CANCELADO) return Forbid();
        if (rol == 4 && solicitud.EventType != TipoEventoTicket.CREADO) return Forbid();
        if (rol == 2 && solicitud.EventType is TipoEventoTicket.ASIGNADO or TipoEventoTicket.REASIGNADO or TipoEventoTicket.PROGRAMADO or TipoEventoTicket.REPROGRAMADO) return Forbid();
        if (solicitud.EventType is TipoEventoTicket.SEGUIMIENTO or TipoEventoTicket.EN_ATENCION)
            if (!await tickets.PuedeOperar(usuario, id, ct)) return Forbid();
        var evento = await eventos.Guardar(usuario, id, solicitud, ct);
        return evento is null ? NotFound() : Ok(new { id = evento.Value });
    }
}
