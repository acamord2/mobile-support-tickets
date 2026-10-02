using Tickets.Api.Data.Connections;
using Tickets.Api.Models;

namespace Tickets.Api.Data;

/// <summary>Implementa la lectura PostgreSQL solicitando una conexión por contrato.</summary>
/// <param name="databaseConnection">Proveedor inyectado de conexiones abiertas.</param>
public class AccesoUsuariosPostgres(IConexion databaseConnection) : IAccesoUsuarios
{
    /// <summary>Invoca get_user_by_username con un parámetro DbCommand y materializa Usuario.</summary>
    /// <param name="username">Nombre exacto recibido por el contrato de acceso.</param>
    /// <param name="cancellationToken">Cancela la consulta si termina la solicitud.</param>
    /// <returns>Usuario encontrado o null cuando no existe ese nombre.</returns>
    public async Task<Usuario?> GetByUsernameAsync(string username, CancellationToken cancellationToken = default)
    {
        await using var connection = await databaseConnection.OpenConnectionAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT f.*, u."RoleId", u."IsActive", r."Name" AS "Role"
            FROM public.get_user_by_username(@username) f
            JOIN public."Users" u ON u."Id" = f."Id"
            JOIN public."Roles" r ON r."Id" = u."RoleId"
            WHERE u."IsActive" = 1
            """;
        var parameter = command.CreateParameter();
        parameter.ParameterName = "username";
        parameter.Value = username;
        command.Parameters.Add(parameter);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;

        var user = new Usuario
        {
            Id = reader.GetInt32(reader.GetOrdinal("Id")),
            Username = reader.GetString(reader.GetOrdinal("Username")),
            PasswordHash = reader.GetString(reader.GetOrdinal("PasswordHash")),
            Name = reader.GetString(reader.GetOrdinal("Name")),
            RoleId = reader.GetInt32(reader.GetOrdinal("RoleId")),
            IsActive = reader.GetInt16(reader.GetOrdinal("IsActive")),
            Role = reader.GetString(reader.GetOrdinal("Role"))
        };
        if (await reader.ReadAsync(cancellationToken))
            throw new InvalidOperationException("La consulta de usuario devolvió más de un resultado.");
        return user;
    }
}
