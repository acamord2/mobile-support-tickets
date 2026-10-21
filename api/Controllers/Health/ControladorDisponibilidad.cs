using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tickets.Api.Data.Connections;

namespace Tickets.Api.Controllers.Health;

/// <summary>Distingue capacidad de consulta y escritura sin emitir autorización ni consultar usuarios.</summary>
[ApiController, AllowAnonymous, Route("api/health/disponibilidad")]
public sealed class ControladorDisponibilidad(IConexion conexion) : ControllerBase
{
    /// <summary>Devuelve capacidades orientativas; cada operación conserva su propia comprobación y manejo de fallo.</summary>
    [HttpGet]
    public async Task<IActionResult> Obtener(CancellationToken ct)
    {
        bool escritura = false, lectura = false;
        try { await using var cn = await conexion.OpenConnectionAsync(ct); escritura = true; }
        catch (Exception e) when (e is System.Data.Common.DbException or TimeoutException) { }
        try { lectura = await conexion.EjecutarLecturaAsync(async (cn, tx, token) =>
        {
            await using var cmd = cn.CreateCommand(); cmd.Transaction = tx; cmd.CommandText = "SELECT 1";
            return (int)(await cmd.ExecuteScalarAsync(token))! == 1;
        }, ct); }
        catch (Exception e) when (e is System.Data.Common.DbException or TimeoutException) { }
        var datos = new { modo = escritura && lectura ? "completo" : lectura ? "solo_consultas" : "sin_servicio", lectura, escritura };
        return lectura ? Ok(datos) : StatusCode(503, datos);
    }
}
