using Tickets.Api.Models;

namespace Tickets.Api.Data;

/// <summary>Permite que la autenticación consuma datos sin conocer el proveedor SQL.</summary>
public interface IAccesoUsuarios
{
    /// <summary>Busca un usuario por su nombre mediante la fuente de datos que determine la implementación.</summary>
    /// <param name="username">Nombre exacto utilizado para localizar al usuario.</param>
    /// <param name="cancellationToken">Permite cancelar la operación de acceso a datos.</param>
    /// <returns>Usuario encontrado, incluido su hash interno, o null si no existe.</returns>
    Task<Usuario?> GetByUsernameAsync(string username, CancellationToken cancellationToken = default);
}
