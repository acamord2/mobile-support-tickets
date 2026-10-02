using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.DTOs;
using Tickets.Api.Services;

namespace Tickets.Api.Controllers.Health;

/// <summary>Delega en el contrato de servicio para no conocer SQL, proveedor ni credenciales.</summary>
/// <param name="databaseHealth">Servicio que comprueba acceso a la base configurada.</param>
[ApiController]
[Route("api/health/database")]
public class ControladorSaludBaseDatos(IServicioSaludBaseDatos databaseHealth) : ControllerBase
{
    /// <summary>Traduce el resultado del servicio a 200 o 503 con un DTO público mínimo; no requiere JWT porque verifica infraestructura antes de usar funcionalidades y no devuelve detalles técnicos que puedan revelar información sensible.</summary>
    /// <param name="cancellationToken">Propaga la cancelación HTTP a la comprobación de conexión.</param>
    /// <returns>200 con connected o 503 con unavailable, sin información de configuración.</returns>
    [AllowAnonymous]
    [HttpGet]
    [ProducesResponseType<RespuestaSaludBaseDatos>(StatusCodes.Status200OK)]
    [ProducesResponseType<RespuestaSaludBaseDatos>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<RespuestaSaludBaseDatos>> Database(CancellationToken cancellationToken)
    {
        var connected = await databaseHealth.CanConnectAsync(cancellationToken);
        return connected
            ? Ok(new RespuestaSaludBaseDatos("ok", "connected"))
            : StatusCode(StatusCodes.Status503ServiceUnavailable,
                new RespuestaSaludBaseDatos("error", "unavailable"));
    }
}
