using System.Data;
using System.Data.Common;
using Npgsql;
using Microsoft.Extensions.Options;
using Tickets.Api.Services;

namespace Tickets.Api.Data.Connections;

/// <summary>Centraliza Npgsql y secretos; separa conexiones sin trasladar autenticación ni escrituras al standby.</summary>
public sealed class Conexion : IConexion
{
    private readonly string escritura;
    private readonly string? lectura;
    private readonly string? consultaPrimaria;
    private readonly bool lecturasEnPrimario;
    private readonly bool fallback;
    private readonly IHttpContextAccessor? contexto;

    /// <summary>Prefiere Escritura, conserva el selector legado y construye el fallback con las credenciales de consulta.</summary>
    /// <param name="configuration">Configuración externa del host; nunca se registran sus valores.</param>
    /// <param name="seleccion">Selectores compatibles con DefaultConnection.</param>
    /// <param name="contexto">Permite solicitar consistencia inmediata sin cambiar URLs ni contratos de respuesta.</param>
    public Conexion(IConfiguration configuration, IOptions<ConfiguracionSecretsApi> seleccion, IHttpContextAccessor? contexto = null)
    {
        var opciones = seleccion.Value;
        var valor = configuration[opciones.ClaveConexionEscritura];
        if (string.IsNullOrWhiteSpace(valor)) valor = configuration[opciones.ClaveConexionBaseDatos];
        if (string.IsNullOrWhiteSpace(valor)) throw new InvalidOperationException("Falta la conexión de escritura.");
        var principal = Preparar(valor);
        escritura = principal.ConnectionString;
        var consulta = configuration[opciones.ClaveConexionLectura];
        if (!string.IsNullOrWhiteSpace(consulta))
        {
            var secundaria = Preparar(consulta);
            if (secundaria.Username == principal.Username) throw new InvalidOperationException("La cuenta de consulta debe ser independiente.");
            lectura = secundaria.ConnectionString;
            secundaria.Host = principal.Host;
            secundaria.Port = principal.Port;
            consultaPrimaria = secundaria.ConnectionString;
        }
        lecturasEnPrimario = opciones.LecturasEnPrimario;
        fallback = opciones.PermitirFallbackLectura;
        this.contexto = contexto;
    }

    /// <summary>Acota apertura y comandos, mantiene pooling y desactiva exposición de parámetros y credenciales.</summary>
    private static NpgsqlConnectionStringBuilder Preparar(string cadena) => new(cadena)
    {
        PersistSecurityInfo = false, IncludeErrorDetail = false, LogParameters = false,
        Timeout = 2, CommandTimeout = 3, CancellationTimeout = 500
    };

    /// <summary>Construye y abre NpgsqlConnection primaria con cancelación y devuelve el tipo común.</summary>
    /// <param name="cancellationToken">Cancela la apertura si termina la solicitud.</param>
    /// <returns>Conexión de escritura abierta, sin fallback ni reintentos.</returns>
    public async Task<DbConnection> OpenConnectionAsync(CancellationToken cancellationToken = default)
    {
        var connection = new NpgsqlConnection(escritura);
        try { await connection.OpenAsync(cancellationToken); return connection; }
        catch { await connection.DisposeAsync(); throw; }
    }

    /// <summary>Materializa una lectura completa en RR/READ ONLY; reintenta como máximo una vez en el primario con la misma cuenta consultora.</summary>
    public async Task<T> EjecutarLecturaAsync<T>(Func<DbConnection, DbTransaction, CancellationToken, Task<T>> consulta, CancellationToken cancellationToken = default)
    {
        using var limite = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        limite.CancelAfter(TimeSpan.FromSeconds(7));
        // Compatibilidad temporal: sin Lectura configurada, conservar el comportamiento primario anterior.
        if (lectura is null) return await Intentar(escritura, false, consulta, limite.Token);
        var inmediata = contexto?.HttpContext?.Request.Headers["X-Consistencia"].ToString() == "inmediata"
            || contexto?.HttpContext?.Request.Query["consistencia"].ToString() == "inmediata";
        if (lecturasEnPrimario || inmediata) return await Intentar(consultaPrimaria!, false, consulta, limite.Token);
        try
        {
            using var intento = CancellationTokenSource.CreateLinkedTokenSource(limite.Token);
            intento.CancelAfter(TimeSpan.FromSeconds(3));
            return await Intentar(lectura, true, consulta, intento.Token);
        }
        catch (Exception error) when (fallback && contexto?.HttpContext?.Items.ContainsKey(ContinuidadConsultas.PrimarioNoDisponible) != true && !limite.IsCancellationRequested &&
            (error is NpgsqlException { IsTransient: true } or TimeoutException ||
             error is OperationCanceledException && !cancellationToken.IsCancellationRequested))
        {
            return await Intentar(consultaPrimaria!, false, consulta, limite.Token);
        }
    }

    /// <summary>Comprueba el rol físico del servidor y comparte snapshot/transacción entre todas las consultas de la respuesta.</summary>
    private async Task<T> Intentar<T>(string cadena, bool standby, Func<DbConnection, DbTransaction, CancellationToken, Task<T>> consulta, CancellationToken ct)
    {
        await using var cn = new NpgsqlConnection(cadena);
        await cn.OpenAsync(ct);
        await using var tx = await cn.BeginTransactionAsync(IsolationLevel.RepeatableRead, ct);
        await using (var cmd = cn.CreateCommand())
        {
            cmd.Transaction = tx;
            cmd.CommandText = "SET TRANSACTION READ ONLY";
            await cmd.ExecuteNonQueryAsync(ct);
            cmd.CommandText = "SELECT pg_is_in_recovery()";
            if ((bool)(await cmd.ExecuteScalarAsync(ct))! != standby)
                throw new InvalidOperationException("El servidor no tiene el rol físico esperado; no se continúa automáticamente.");
        }
        if (contexto?.HttpContext is { } http) http.Response.Headers["X-Destino-Lectura"] = standby ? "secundaria" : "primaria";
        var resultado = await consulta(cn, tx, ct);
        await tx.CommitAsync(ct);
        return resultado;
    }
}
