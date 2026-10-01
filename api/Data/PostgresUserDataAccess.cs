using Tickets.Api.Data.Connections;
using Tickets.Api.Models;

namespace Tickets.Api.Data;

/// <summary>
/// Implementa la lectura PostgreSQL solicitando una conexión por contrato.
/// Mantiene SQL y materialización aquí, sin conocer configuración o tipos Npgsql,
/// para que servicios y controllers sigan dependiendo del acceso abstracto.
/// </summary>
/// <param name="databaseConnection">Proveedor inyectado de conexiones abiertas.</param>
public class PostgresUserDataAccess(IConexion databaseConnection) : IUserDataAccess
{
    /// <summary>
    /// Invoca get_user_by_username con un parámetro DbCommand y materializa User.
    /// Dispone conexión, comando y lector al finalizar, incluso ante fallos;
    /// preserva la consulta existente sin interpolar texto recibido del request.
    /// </summary>
    /// <param name="username">Nombre exacto recibido por el contrato de acceso.</param>
    /// <param name="cancellationToken">Cancela la consulta si termina la solicitud.</param>
    /// <returns>Usuario encontrado o null cuando no existe ese nombre.</returns>
    public async Task<User?> GetByUsernameAsync(string username, CancellationToken cancellationToken = default)
    {
        await using var connection = await databaseConnection.OpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT * FROM public.get_user_by_username(@username)";
        var parameter = command.CreateParameter();
        parameter.ParameterName = "username";
        parameter.Value = username;
        command.Parameters.Add(parameter);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;

        var user = new User
        {
            Id = reader.GetInt32(reader.GetOrdinal("Id")),
            Username = reader.GetString(reader.GetOrdinal("Username")),
            PasswordHash = reader.GetString(reader.GetOrdinal("PasswordHash")),
            Name = reader.GetString(reader.GetOrdinal("Name"))
        };
        if (await reader.ReadAsync(cancellationToken))
            throw new InvalidOperationException("La consulta de usuario devolvió más de un resultado.");
        return user;
    }
}
