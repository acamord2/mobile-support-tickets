using System.Data.Common;

namespace Tickets.Api.Data.Connections;

/// <summary>Proporciona conexiones abiertas mediante un contrato común de ADO.NET.</summary>
public interface IConexion
{
    /// <summary>Devuelve DbConnection para permitir consultas sin exponer tipos Npgsql ni agregar propiedades de credenciales al contrato de la aplicación.</summary>
    /// <param name="cancellationToken">Permite cancelar la apertura.</param>
    /// <returns>Conexión abierta que el consumidor debe liberar con await using.</returns>
    Task<DbConnection> OpenConnectionAsync(CancellationToken cancellationToken = default);
    /// <summary>Ejecuta únicamente una consulta replicable completa en snapshot de solo lectura; permite un fallback al primario con la cuenta de consulta.</summary>
    /// <param name="consulta">Materializa el resultado antes de cerrar conexión/transacción; no debe producir efectos externos.</param>
    /// <param name="cancellationToken">Acota el conjunto de intentos y propaga cancelación HTTP.</param>
    Task<T> EjecutarLecturaAsync<T>(Func<DbConnection, DbTransaction, CancellationToken, Task<T>> consulta, CancellationToken cancellationToken = default);
}
