using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.DTOs;
using Tickets.Api.Services;

namespace Tickets.Api.Controllers.Auth;

/// <summary>Expone exclusivamente el endpoint existente de verificación de credenciales.</summary>
/// <param name="authService">Servicio que verifica credenciales de usuarios existentes.</param>
[ApiController]
[Route("api/auth/login")]
public class ControladorLogin(ServicioAutenticacion authService) : ControllerBase
{
    /// <summary>Verifica las credenciales recibidas mediante el servicio de autenticación.</summary>
    /// <param name="request">Nombre de usuario y contraseña a verificar.</param>
    /// <param name="cancellationToken">Propaga la cancelación HTTP al acceso a datos.</param>
    /// <returns>Respuesta pública con JWT o un error de credenciales.</returns>
    [AllowAnonymous]
    [HttpPost]
    [ProducesResponseType<RespuestaLogin>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<RespuestaLogin>> Login(SolicitudLogin request, CancellationToken cancellationToken)
    {
        var response = await authService.LoginAsync(request, cancellationToken);
        return response is null
            ? Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Usuario o contraseña incorrectos.")
            : Ok(response);
    }
}
