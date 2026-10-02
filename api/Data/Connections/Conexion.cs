using System.Data.Common;
using Npgsql;

namespace Tickets.Api.Data.Connections;

/// <summary>Es el único componente activo que utiliza Npgsql y lee la ConnectionString, evitando distribuir credenciales o configuración del proveedor entre capas.</summary>
public sealed class Conexion : IConexion
{
    private readonly string _connectionString;

    /// <summary>Lee DefaultConnection desde configuración y desactiva PersistSecurityInfo.</summary>
    /// <param name="configuration">Configuración central del host ASP.NET Core.</param>
    public Conexion(IConfiguration configuration)
    {
        var configured = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Falta configurar DefaultConnection.");
        var settings = new NpgsqlConnectionStringBuilder(configured)
        {
            PersistSecurityInfo = false
        };
        _connectionString = settings.ConnectionString;
    }

    /// <summary>Construye y abre NpgsqlConnection con cancelación y devuelve el tipo común.</summary>
    /// <param name="cancellationToken">Cancela la apertura si termina la solicitud.</param>
    /// <returns>Conexión PostgreSQL abierta, sin credenciales expuestas por el contrato.</returns>
    public async Task<DbConnection> OpenConnectionAsync(CancellationToken cancellationToken = default)
    {
        var connection = new NpgsqlConnection(_connectionString);
        try
        {
            await connection.OpenAsync(cancellationToken);
            return connection;
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }
}
