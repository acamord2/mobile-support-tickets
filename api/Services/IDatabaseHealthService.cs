namespace Tickets.Api.Services;

/// <summary>
/// Define la comprobación mínima de acceso a la base configurada.
/// Separa el resultado de conectividad del manejo HTTP para que el Controller
/// no conozca conexiones, consultas ni detalles del proveedor PostgreSQL.
/// </summary>
public interface IDatabaseHealthService
{
    /// <summary>
    /// Comprueba si se puede abrir una conexión con la base de datos existente.
    /// La implementación utiliza la infraestructura de conexión configurada sin
    /// consultar tablas, crear estructura ni modificar datos; prueba únicamente
    /// disponibilidad, credenciales y acceso a la base.
    /// </summary>
    /// <param name="cancellationToken">Permite cancelar la comprobación al terminar la solicitud.</param>
    /// <returns>True si se puede conectar; false si la base no está disponible.</returns>
    Task<bool> CanConnectAsync(CancellationToken cancellationToken = default);
}
