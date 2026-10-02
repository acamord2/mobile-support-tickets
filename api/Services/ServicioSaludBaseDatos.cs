using System.Data.Common;
using Tickets.Api.Data.Connections;

namespace Tickets.Api.Services;

/// <summary>Comprueba conectividad con IConexion sin consultar tablas ni duplicar configuración.</summary>
/// <param name="databaseConnection">Proveedor inyectado de conexiones abiertas.</param>
public class ServicioSaludBaseDatos(IConexion databaseConnection) : IServicioSaludBaseDatos
{
    /// <summary>Abre y libera la conexión; oculta fallos de BD y propaga la cancelación.</summary>
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
