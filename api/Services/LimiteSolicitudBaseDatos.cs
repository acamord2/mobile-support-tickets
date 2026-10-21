using Microsoft.AspNetCore.Mvc;

namespace Tickets.Api.Services;

/// <summary>Acota solicitudes y traduce solo indisponibilidad transitoria a503; no oculta errores SQL permanentes.</summary>
public sealed class LimiteSolicitudBaseDatos(RequestDelegate siguiente)
{
    /// <summary>Comparte nueve segundos entre autorización y consultas; no reintenta operaciones ni altera sus resultados.</summary>
    public async Task InvokeAsync(HttpContext context)
    {
        var original = context.RequestAborted;
        using var limite = CancellationTokenSource.CreateLinkedTokenSource(original);
        limite.CancelAfter(TimeSpan.FromSeconds(9));
        context.RequestAborted = limite.Token;
        try { await siguiente(context); }
        catch (Exception error) when (!original.IsCancellationRequested && !context.Response.HasStarted &&
            (error is Npgsql.NpgsqlException { IsTransient: true } or TimeoutException or OperationCanceledException))
        {
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            context.Response.Headers.RetryAfter = "5";
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Status = 503, Title = "La base de datos requerida no está disponible.",
                Extensions = { ["codigo"] = "base_datos_no_disponible" }
            }, CancellationToken.None);
        }
        finally { context.RequestAborted = original; }
    }
}
