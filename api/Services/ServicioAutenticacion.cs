using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Tickets.Api.Data;
using Tickets.Api.DTOs;
using Tickets.Api.Models;

namespace Tickets.Api.Services;

/// <summary>Conserva la infraestructura de verificación de credenciales y emisión JWT.</summary>
/// <param name="users">Contrato independiente del motor para localizar usuarios.</param>
/// <param name="passwordHasher">Implementación estándar que verifica el hash almacenado.</param>
/// <param name="jwtOptions">Opciones de firma, destinatario y vigencia tomadas de configuración.</param>
public class ServicioAutenticacion(
    IAccesoUsuarios users,
    IPasswordHasher<Usuario> passwordHasher,
    IOptions<OpcionesJwt> jwtOptions)
{
    /// <summary>Verifica credenciales de un usuario existente y devuelve un JWT cuando son válidas.</summary>
    /// <param name="request">Credenciales recibidas mediante un DTO, no una entidad de BD.</param>
    /// <param name="cancellationToken">Cancela el acceso a datos al finalizar la solicitud.</param>
    /// <returns>Token y usuario público, o null si las credenciales son incorrectas.</returns>
    public async Task<RespuestaLogin?> LoginAsync(SolicitudLogin request, CancellationToken cancellationToken)
    {
        var user = await users.GetByUsernameAsync(request.Username, cancellationToken);
        if (user is null || user.IsActive != 1 || passwordHasher.VerifyHashedPassword(user, user.PasswordHash, request.Password)
            == PasswordVerificationResult.Failed)
        {
            return null;
        }

        var settings = jwtOptions.Value;
        var now = DateTime.UtcNow;
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString(CultureInfo.InvariantCulture)),
            new Claim("username", user.Username),
            new Claim("name", user.Name),
            new Claim("roleId", user.RoleId.ToString(CultureInfo.InvariantCulture)),
            new Claim("role", user.Role)
        };
        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.Key)),
            SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: settings.Issuer,
            audience: settings.Audience,
            claims: claims,
            notBefore: now,
            expires: now.AddMinutes(settings.ExpirationMinutes),
            signingCredentials: credentials);

        return new RespuestaLogin(
            new JwtSecurityTokenHandler().WriteToken(token),
            new RespuestaUsuario(user.Id, user.Username, user.Name, user.RoleId, user.Role));
    }
}
