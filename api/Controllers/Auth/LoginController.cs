using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.DTOs;
using Tickets.Api.Services;

namespace Tickets.Api.Controllers.Auth;

/// <summary>
/// Expone exclusivamente el endpoint existente de verificación de credenciales.
/// Delega al servicio compartido para separar responsabilidades HTTP sin duplicar
/// hashing, acceso a usuarios o generación del JWT.
/// </summary>
/// <param name="authService">Servicio que verifica credenciales de usuarios existentes.</param>
[ApiController]
[Route("api/auth/login")]
public class LoginController(AuthService authService) : ControllerBase
{
    /// <summary>
    /// Verifica las credenciales recibidas mediante el servicio de autenticación.
    /// ApiController valida el DTO y el servicio comprueba el hash; devuelve 401
    /// ante credenciales incorrectas y solo datos públicos en caso de éxito.
    /// El acceso es anónimo porque este endpoint existente permite obtener el JWT.
    /// </summary>
    /// <param name="request">Nombre de usuario y contraseña a verificar.</param>
    /// <param name="cancellationToken">Propaga la cancelación HTTP al acceso a datos.</param>
    /// <returns>Respuesta pública con JWT o un error de credenciales.</returns>
    [AllowAnonymous]
    [HttpPost]
    [ProducesResponseType<LoginResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var response = await authService.LoginAsync(request, cancellationToken);
        return response is null
            ? Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Usuario o contraseña incorrectos.")
            : Ok(response);
    }
}
