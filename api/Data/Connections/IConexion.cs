using System.Data.Common;

namespace Tickets.Api.Data.Connections;

/// <summary>
/// Proporciona conexiones abiertas mediante un contrato común de ADO.NET.
/// DataAccess y servicios dependen de este contrato para no configurar ni
/// acoplarse al motor PostgreSQL; cada consumidor debe disponer su conexión.
/// </summary>
public interface IConexion
{
    /// <summary>
    /// Crea y abre una conexión usando la configuración privada del proveedor.
    /// Devuelve DbConnection para permitir consultas sin exponer tipos Npgsql
    /// ni agregar propiedades de credenciales al contrato de la aplicación.
    /// </summary>
    /// <param name="cancellationToken">Permite cancelar la apertura.</param>
    /// <returns>Conexión abierta que el consumidor debe liberar con await using.</returns>
    Task<DbConnection> OpenConnectionAsync(CancellationToken cancellationToken = default);
}
