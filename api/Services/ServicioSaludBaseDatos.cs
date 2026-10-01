using System.Data.Common;
using Tickets.Api.Data.Connections;

namespace Tickets.Api.Services;

/// <summary>
/// Comprueba acceso mediante el mismo contrato de conexión usado por DataAccess.
/// Abre y dispone una conexión sin consultar tablas ni conocer el proveedor,
/// para comprobar disponibilidad sin duplicar mecanismos de configuración.
/// </summary>
/// <param name="databaseConnection">Proveedor inyectado de conexiones abiertas.</param>
public class ServicioSaludBaseDatos(IConexion databaseConnection) : IServicioSaludBaseDatos
{
    /// <summary>
    /// Solicita una conexión abierta y la libera inmediatamente mediante await using.
    /// Convierte fallos de base de datos en false sin registrar credenciales ni
    /// devolver excepciones al cliente; la cancelación de la solicitud se propaga.
    /// </summary>
    /// <param name="cancellationToken">Cancela la comprobación si finaliza la solicitud HTTP.</param>
    /// <returns>True cuando se puede conectar; false ante una conexión no disponible.</returns>
    public async Task<bool> CanConnectAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = await databaseConnection.OpenConnectionAsync(cancellationToken);
            return true;
        }
        catch (DbException)
        {
            return false;
        }
    }
}
