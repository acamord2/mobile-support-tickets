using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.DTOs;

namespace Tickets.Api.Controllers.Auth;

/// <summary>
/// Expone exclusivamente la identidad del técnico contenida en el JWT validado.
/// Se mantiene independiente del login y de PostgreSQL para localizar este
/// endpoint sin duplicar autenticación o realizar consultas innecesarias.
/// </summary>
[ApiController]
[Route("api/auth/me")]
public class MeController : ControllerBase
{
    /// <summary>
    /// Devuelve la identidad contenida en el JWT validado por el middleware.
    /// Lee y comprueba sub, username y name sin consultar la BD; rechaza claims
    /// incompletos para no presentar una identidad inválida como autenticada.
    /// Los datos corresponden al momento en que se emitió el token.
    /// </summary>
    /// <returns>Id, username y name, o 401 cuando falta una identidad válida.</returns>
    [Authorize]
    [HttpGet]
    [ProducesResponseType<UserResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public ActionResult<UserResponse> Me()
    {
        var username = User.FindFirstValue("username");
        var name = User.FindFirstValue("name");
        if (!int.TryParse(User.FindFirstValue(JwtRegisteredClaimNames.Sub),
                NumberStyles.None, CultureInfo.InvariantCulture, out var id)
            || id <= 0 || string.IsNullOrEmpty(username) || string.IsNullOrEmpty(name))
        {
            return Unauthorized();
        }

        return Ok(new UserResponse(id, username, name));
    }
}
