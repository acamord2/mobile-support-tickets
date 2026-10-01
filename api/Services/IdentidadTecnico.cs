using System.Security.Claims;
namespace Tickets.Api.Services;
/// <summary>Extrae exclusivamente el identificador sub validado por JWT para evitar aceptar identidad enviada desde Flutter.</summary>
public static class IdentidadTecnico
{
    /// <summary>Devuelve Id positivo o cero inválido; los endpoints rechazan identidades ausentes antes de consultar datos.</summary>
    public static int Obtener(ClaimsPrincipal usuario) => int.TryParse(usuario.FindFirstValue("sub"),out var id) && id>0 ? id:0;
}
