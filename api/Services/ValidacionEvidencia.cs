using Tickets.Api.DTOs;
namespace Tickets.Api.Services;
/// <summary>Valida fotografía JPEG y el tamaño real antes de persistir; centraliza el límite para no confiar en longitud Base64 ni en el cliente.</summary>
public static class ValidacionEvidencia
{
    public const int MaximoBytes = 1024 * 1024;
    /// <summary>Rechaza prefijos, Base64 incompleto, MIME distinto y bytes que exceden 1 MB; admite evidencia descriptiva sin fotografía.</summary>
    public static bool Valida(SolicitudEvidencia solicitud)
    {
        if(string.IsNullOrWhiteSpace(solicitud.Description)) return false;
        if(solicitud.PhotoBase64 is null) return solicitud.Mime is null;
        if(solicitud.Mime != "image/jpeg" || solicitud.PhotoBase64.Length > ((MaximoBytes+2)/3)*4) return false;
        try
        {
            var bytes=Convert.FromBase64String(solicitud.PhotoBase64);
            return bytes.Length is > 4 and <= MaximoBytes && bytes[0]==0xff && bytes[1]==0xd8 && bytes[^2]==0xff && bytes[^1]==0xd9;
        }
        catch(FormatException) { return false; }
    }
}
