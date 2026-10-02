using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.DTOs;
using Tickets.Api.Data;

namespace Tickets.Api.Controllers.Auth;

/// <summary>Expone identidad pública del técnico autenticado y comprueba actividad actual.</summary>
[ApiController]
[Route("api/auth/me")]
public class ControladorIdentidad(IAccesoUsuarios usuarios) : ControllerBase
{
    /// <summary>Devuelve la identidad contenida en el JWT validado por el middleware.</summary>
    /// <returns>Id, username y name, o 401 cuando falta una identidad válida.</returns>
    [Authorize]
    [HttpGet]
    [ProducesResponseType<RespuestaUsuario>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<RespuestaUsuario>> Me(CancellationToken cancellationToken)
    {
        var username = User.FindFirstValue("username");
        var name = User.FindFirstValue("name");
        if (!int.TryParse(User.FindFirstValue(JwtRegisteredClaimNames.Sub),
                NumberStyles.None, CultureInfo.InvariantCulture, out var id)
            || id <= 0 || string.IsNullOrEmpty(username) || string.IsNullOrEmpty(name))
        {
            return Unauthorized();
        }

        var actual = await usuarios.GetByUsernameAsync(username, cancellationToken);
        if (actual is null || actual.Id != id || actual.IsActive != 1) return Unauthorized();
        return Ok(new RespuestaUsuario(actual.Id, actual.Username, actual.Name, actual.RoleId, actual.Role));
    }
}
