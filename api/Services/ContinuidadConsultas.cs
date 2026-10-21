using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using System.Security.Claims;

namespace Tickets.Api.Services;

/// <summary>Conserva por120 segundos autorizaciones primarias asociadas al JWT; nunca renueva permisos desde la réplica.</summary>
public sealed class ContinuidadConsultas(IHttpContextAccessor contexto, TimeProvider reloj)
{
    private sealed record Entrada(object Valor, DateTimeOffset Hasta);
    private readonly ConcurrentDictionary<string, Entrada> entradas = new();
    public const string PrimarioNoDisponible = "PrimarioNoDisponible";

    /// <summary>Lee primero el primario; solo ante caída transitoria permite el último alcance del mismo JWT en un GET protegido.</summary>
    public async Task<T> ObtenerAsync<T>(string categoria, int usuario, Func<Task<T>> primaria, CancellationToken ct)
    {
        var http = contexto.HttpContext;
        var token = http?.Request.Headers.Authorization.ToString();
        var permitido = http is not null && HttpMethods.IsGet(http.Request.Method)
            && !http.Request.Path.StartsWithSegments("/api/auth")
            && http.User.Identity?.IsAuthenticated == true
            && http.User.FindFirstValue("sub") == usuario.ToString(System.Globalization.CultureInfo.InvariantCulture)
            && !string.IsNullOrWhiteSpace(token);
        if (!permitido) return await primaria();
        var prefijo = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token!))) + ":";
        var clave = prefijo + categoria;
        if (!http!.Items.ContainsKey(PrimarioNoDisponible))
        {
            try
            {
                var valor = await primaria();
                if (categoria == "rol" && valor is int rol &&
                    (rol == 0 || entradas.TryGetValue(clave, out var anterior) && !Equals(anterior.Valor, rol)))
                    foreach (var k in entradas.Keys.Where(k => k.StartsWith(prefijo))) entradas.TryRemove(k, out _);
                if (entradas.Count > 3000) entradas.Clear(); // Expulsión cerrada: perder caché nunca concede acceso.
                if (!(categoria == "rol" && valor is int id && id == 0))
                    entradas[clave] = new Entrada(valor!, reloj.GetUtcNow().AddSeconds(120));
                return valor;
            }
            catch (Exception e) when (!ct.IsCancellationRequested &&
                e is Npgsql.NpgsqlException { IsTransient: true } or TimeoutException)
            {
                http.Items[PrimarioNoDisponible] = true;
            }
        }
        ct.ThrowIfCancellationRequested();
        if (!entradas.TryGetValue(clave, out var entrada) || reloj.GetUtcNow() >= entrada.Hasta || entrada.Valor is not T resultado)
            throw new TimeoutException("No existe autorización primaria temporal vigente.");
        http.Response.Headers["X-Modo"] = "solo-consultas";
        http.Response.Headers["X-Autorizacion"] = "temporal-no-confirmada";
        http.Response.Headers.CacheControl = "no-store";
        return resultado;
    }
}
