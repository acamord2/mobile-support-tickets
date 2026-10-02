using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Primitives;
using Tickets.Api.Data.Connections;
using Tickets.Api.Services;

/// <summary>Comprueba la selección real de claves y el arranque sin red ni secrets locales.</summary>
internal static class PruebasConfiguracionSecrets
{
    public static void Ejecutar()
    {
        var aprobadas = 0;
        void Prueba(string nombre, Action comprobar)
        {
            comprobar();
            aprobadas++;
            Console.WriteLine($"Correcto: {nombre}");
        }

        Prueba("Defaults compatibles y binding JWT conservado", () =>
        {
            var datos = Datos();
            var configuracion = new ConfiguracionObservada(new ConfigurationBuilder().AddInMemoryCollection(datos).Build());
            using var servicios = Servicios(configuracion);
            servicios.GetRequiredService<IStartupValidator>().Validate();
            var seleccion = servicios.GetRequiredService<IOptions<ConfiguracionSecretsApi>>().Value;
            var jwt = servicios.GetRequiredService<IOptions<OpcionesJwt>>().Value;
            Exigir(seleccion.ClaveConexionBaseDatos == "ConnectionStrings:DefaultConnection" && seleccion.ClaveJwt == "Jwt:Key");
            Exigir(jwt.Key == datos["Jwt:Key"] && jwt.Issuer == "Pruebas" && jwt.Audience == "Pruebas" && jwt.ExpirationMinutes == 60);
            configuracion.Lecturas.Clear();
            _ = servicios.GetRequiredService<IConexion>();
            Exigir(configuracion.Lecturas.SequenceEqual(["ConnectionStrings:DefaultConnection"]));
        });

        Prueba("Conexión y JWT alternativos prevalecen sobre defaults", () =>
        {
            var datos = Datos();
            datos["SecretsApi:ClaveConexionBaseDatos"] = "ConnectionStrings:ApiPruebas";
            datos["SecretsApi:ClaveJwt"] = "Jwt:ApiPruebas";
            datos["ConnectionStrings:ApiPruebas"] = "Host=localhost;Database=pruebas_alternativas";
            datos["Jwt:ApiPruebas"] = new string('B', 48);
            var configuracion = new ConfiguracionObservada(new ConfigurationBuilder().AddInMemoryCollection(datos).Build());
            using var servicios = Servicios(configuracion);
            servicios.GetRequiredService<IStartupValidator>().Validate();
            Exigir(servicios.GetRequiredService<IOptions<OpcionesJwt>>().Value.Key == datos["Jwt:ApiPruebas"]);
            configuracion.Lecturas.Clear();
            _ = servicios.GetRequiredService<IConexion>();
            Exigir(configuracion.Lecturas.SequenceEqual(["ConnectionStrings:ApiPruebas"]));
        });

        var casos = new (string Nombre, string Clave, string? Valor, string Error)[]
        {
            ("Nombre conexión vacío", "SecretsApi:ClaveConexionBaseDatos", "", "No se configuró SecretsApi:ClaveConexionBaseDatos."),
            ("Nombre conexión en blanco", "SecretsApi:ClaveConexionBaseDatos", " ", "No se configuró SecretsApi:ClaveConexionBaseDatos."),
            ("Nombre JWT vacío", "SecretsApi:ClaveJwt", "", "No se configuró SecretsApi:ClaveJwt."),
            ("Nombre JWT en blanco", "SecretsApi:ClaveJwt", " ", "No se configuró SecretsApi:ClaveJwt."),
            ("Valor conexión ausente", "ConnectionStrings:DefaultConnection", null, "No existe un valor para la clave configurada como conexión."),
            ("Valor conexión vacío", "ConnectionStrings:DefaultConnection", "", "No existe un valor para la clave configurada como conexión."),
            ("Valor conexión en blanco", "ConnectionStrings:DefaultConnection", " ", "No existe un valor para la clave configurada como conexión."),
            ("Valor JWT ausente", "Jwt:Key", null, "No existe un valor para la clave configurada como JWT."),
            ("Valor JWT vacío", "Jwt:Key", "", "No existe un valor para la clave configurada como JWT."),
            ("Valor JWT en blanco", "Jwt:Key", " ", "No existe un valor para la clave configurada como JWT."),
            ("JWT corto", "Jwt:Key", new string('C', 31), "La clave JWT seleccionada debe tener al menos 32 bytes."),
            ("Conexión alternativa ausente sin fallback", "SecretsApi:ClaveConexionBaseDatos", "ConnectionStrings:Inexistente", "No existe un valor para la clave configurada como conexión."),
            ("JWT alternativo ausente sin fallback", "SecretsApi:ClaveJwt", "Jwt:Inexistente", "No existe un valor para la clave configurada como JWT.")
        };
        foreach (var caso in casos)
            Prueba(caso.Nombre, () =>
            {
                var datos = Datos();
                datos[caso.Clave] = caso.Valor;
                using var servicios = Servicios(new ConfigurationBuilder().AddInMemoryCollection(datos).Build());
                try
                {
                    servicios.GetRequiredService<IStartupValidator>().Validate();
                    throw new InvalidOperationException("La configuración inválida permitió iniciar.");
                }
                catch (Exception error) when (error is OptionsValidationException or AggregateException)
                {
                    var errores = error is AggregateException varios
                        ? varios.Flatten().InnerExceptions.OfType<OptionsValidationException>()
                        : new[] { (OptionsValidationException)error };
                    Exigir(errores.SelectMany(validacion => validacion.Failures)
                        .Any(mensaje => mensaje.Contains(caso.Error, StringComparison.Ordinal)));
                }
            });

        Prueba("JWT de 32 bytes admitido", () =>
        {
            var datos = Datos();
            datos["Jwt:Key"] = new string('D', 32);
            using var servicios = Servicios(new ConfigurationBuilder().AddInMemoryCollection(datos).Build());
            servicios.GetRequiredService<IStartupValidator>().Validate();
        });

        Prueba("Variables de entorno seleccionan claves alternativas", () =>
        {
            const string prefijo = "PRUEBA_SECRETS_API_";
            var variables = new Dictionary<string, string>
            {
                [prefijo + "SecretsApi__ClaveConexionBaseDatos"] = "ConnectionStrings:ApiEntorno",
                [prefijo + "SecretsApi__ClaveJwt"] = "Jwt:ApiEntorno",
                [prefijo + "ConnectionStrings__ApiEntorno"] = "Host=localhost;Database=pruebas_entorno",
                [prefijo + "Jwt__ApiEntorno"] = new string('E', 48)
            };
            var anteriores = variables.Keys.ToDictionary(nombre => nombre, Environment.GetEnvironmentVariable);
            try
            {
                foreach (var variable in variables) Environment.SetEnvironmentVariable(variable.Key, variable.Value);
                var configuracion = new ConfiguracionObservada(new ConfigurationBuilder()
                    .AddInMemoryCollection(Datos()).AddEnvironmentVariables(prefijo).Build());
                using var servicios = Servicios(configuracion);
                servicios.GetRequiredService<IStartupValidator>().Validate();
                Exigir(servicios.GetRequiredService<IOptions<OpcionesJwt>>().Value.Key == variables[prefijo + "Jwt__ApiEntorno"]);
                configuracion.Lecturas.Clear();
                _ = servicios.GetRequiredService<IConexion>();
                Exigir(configuracion.Lecturas.SequenceEqual(["ConnectionStrings:ApiEntorno"]));
            }
            finally
            {
                foreach (var variable in anteriores) Environment.SetEnvironmentVariable(variable.Key, variable.Value);
            }
        });
        Console.WriteLine($"Configuración: {aprobadas} pruebas aprobadas; sin red, BD ni User Secrets.");
    }

    private static Dictionary<string, string?> Datos() => new()
    {
        ["ConnectionStrings:DefaultConnection"] = "Host=localhost;Database=pruebas",
        ["Jwt:Key"] = new string('A', 48),
        ["Jwt:Issuer"] = "Pruebas",
        ["Jwt:Audience"] = "Pruebas",
        ["Jwt:ExpirationMinutes"] = "60"
    };

    private static ServiceProvider Servicios(IConfiguration configuracion)
    {
        var servicios = new ServiceCollection();
        servicios.AddSingleton(configuracion);
        servicios.AddScoped<IConexion, Conexion>();
        ConfiguracionSecretsApi.Registrar(servicios, configuracion);
        return servicios.BuildServiceProvider();
    }

    private static void Exigir(bool valido)
    {
        if (!valido) throw new InvalidOperationException("La selección de configuración no coincide con lo esperado.");
    }

    /// <summary>Observa qué nombre consulta Conexion sin exponer valores ni abrir PostgreSQL.</summary>
    private sealed class ConfiguracionObservada(IConfiguration origen) : IConfiguration
    {
        public List<string> Lecturas { get; } = [];
        public string? this[string clave]
        {
            get { Lecturas.Add(clave); return origen[clave]; }
            set => origen[clave] = value;
        }
        public IEnumerable<IConfigurationSection> GetChildren() => origen.GetChildren();
        public IChangeToken GetReloadToken() => origen.GetReloadToken();
        public IConfigurationSection GetSection(string clave) => origen.GetSection(clave);
    }
}
