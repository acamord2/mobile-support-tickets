using Tickets.Api.Models;

namespace Tickets.Api.Data;

/// <summary>
/// Define el contrato mínimo para localizar usuarios en la persistencia.
/// Permite que la autenticación consuma datos sin conocer el proveedor SQL.
/// </summary>
public interface IUserDataAccess
{
    /// <summary>
    /// Busca un usuario por su nombre mediante la fuente de datos que determine
    /// la implementación. Mantiene al consumidor independiente del motor de BD
    /// para poder sustituir el acceso a PostgreSQL sin cambiar el contrato.
    /// </summary>
    /// <param name="username">Nombre exacto utilizado para localizar al usuario.</param>
    /// <param name="cancellationToken">Permite cancelar la operación de acceso a datos.</param>
    /// <returns>Usuario encontrado, incluido su hash interno, o null si no existe.</returns>
    Task<User?> GetByUsernameAsync(string username, CancellationToken cancellationToken = default);
}
