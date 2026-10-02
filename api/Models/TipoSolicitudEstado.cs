namespace Tickets.Api.Models;
/// <summary>Centraliza claves SQL/HTTP de las solicitudes y decisiones para evitar valores dispersos.</summary>
public static class TipoSolicitudEstado
{
    public const string Resolucion = "SOLICITUD_RESOLUCION", Cancelacion = "SOLICITUD_CANCELACION";
    public const string Pendiente = "PENDIENTE", Aprobada = "APROBADA", Rechazada = "RECHAZADA";
}
