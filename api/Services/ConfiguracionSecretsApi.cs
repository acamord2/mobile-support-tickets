using System.ComponentModel.DataAnnotations;
using System.Text;
using Microsoft.Extensions.Options;

namespace Tickets.Api.Services;

/// <summary>Selecciona claves de configuración externas; nunca almacena sus valores secretos.</summary>
public class ConfiguracionSecretsApi
{
    [Required(ErrorMessage = "No se configuró SecretsApi:ClaveConexionBaseDatos.")]
    public string ClaveConexionBaseDatos { get; set; } = "ConnectionStrings:DefaultConnection";

    [Required(ErrorMessage = "No se configuró SecretsApi:ClaveJwt.")]
    public string ClaveJwt { get; set; } = "Jwt:Key";

    /// <summary>Valida las referencias al iniciar y entrega a JWT únicamente la clave seleccionada.</summary>
    public static void Registrar(IServiceCollection servicios, IConfiguration configuracion)
    {
        servicios.AddOptions<ConfiguracionSecretsApi>()
            .Bind(configuracion.GetSection("SecretsApi"))
            .ValidateDataAnnotations()
            .Validate(opciones => string.IsNullOrWhiteSpace(opciones.ClaveConexionBaseDatos)
                || !string.IsNullOrWhiteSpace(configuracion[opciones.ClaveConexionBaseDatos]),
                "No existe un valor para la clave configurada como conexión.")
            .Validate(opciones => string.IsNullOrWhiteSpace(opciones.ClaveJwt)
                || !string.IsNullOrWhiteSpace(configuracion[opciones.ClaveJwt]),
                "No existe un valor para la clave configurada como JWT.")
            .Validate(opciones => string.IsNullOrWhiteSpace(opciones.ClaveJwt)
                || string.IsNullOrWhiteSpace(configuracion[opciones.ClaveJwt])
                || Encoding.UTF8.GetByteCount(configuracion[opciones.ClaveJwt]!) >= 32,
                "La clave JWT seleccionada debe tener al menos 32 bytes.")
            .ValidateOnStart();

        servicios.AddOptions<OpcionesJwt>()
            .Bind(configuracion.GetSection("Jwt"))
            .Configure<IOptions<ConfiguracionSecretsApi>>((jwt, seleccion) =>
                jwt.Key = configuracion[seleccion.Value.ClaveJwt] ?? string.Empty)
            .ValidateDataAnnotations()
            .Validate(jwt => Encoding.UTF8.GetByteCount(jwt.Key) >= 32,
                "La clave JWT seleccionada debe tener al menos 32 bytes.")
            .ValidateOnStart();
    }
}
