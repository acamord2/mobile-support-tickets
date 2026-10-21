using Tickets.Api.Services;
using Tickets.Api.Data.Connections;
using Tickets.Api.DTOs;
namespace Tickets.Api.Data;
/// <summary>Consulta equipo real y asigna bajo reglas sencillas de rol, relación y estado.</summary>
public sealed class AccesoCoordinacionPostgres(IConexion conexion, ContinuidadConsultas? continuidad = null)
{
    /// <summary>Entrega solo técnicos activos relacionados; administrador obtiene visibilidad global sin relación artificial.</summary>
    public async Task<List<RespuestaTecnico>> Tecnicos(int usuario, CancellationToken ct)
    {
        async Task<int[]> Autorizar()
        {
        var ids = new List<int>();
        await using (var primaria = await conexion.OpenConnectionAsync(ct))
        {
            await using var cmd = primaria.CreateCommand();
        cmd.CommandText = """
          SELECT tecnico."Id"
          FROM public."Users" tecnico JOIN public."Users" actor ON actor."Id"=@usuario
          WHERE actor."IsActive"=1 AND (tecnico."RoleId"=2 OR (actor."RoleId"=1 AND tecnico."RoleId"=3)) AND tecnico."IsActive"=1
          AND (actor."RoleId"=1 OR (actor."RoleId"=3 AND EXISTS(SELECT 1 FROM public."CoordinatorTechnicians" c WHERE c."CoordinatorUserId"=@usuario AND c."TechnicianUserId"=tecnico."Id")))
          ORDER BY tecnico."Name",tecnico."Id"
          """;
            AccesoTicketsPostgres.Parametro(cmd, "usuario", usuario);
            await using var lector = await cmd.ExecuteReaderAsync(ct);
            while (await lector.ReadAsync(ct)) ids.Add(lector.GetInt32(0));
        }
            return ids.ToArray();
        }
        var permitidos = continuidad is null ? await Autorizar()
            : await continuidad.ObtenerAsync("tecnicos", usuario, Autorizar, ct);
        return await conexion.EjecutarLecturaAsync(async (cn, tx, lecturaCt) =>
        {
            await using var cmd = cn.CreateCommand(); cmd.Transaction = tx;
            cmd.CommandText = """
              SELECT tecnico."Id",tecnico."Name",CASE WHEN actor."RoleId"=3 THEN actor."Id" ELSE NULL END
              FROM public."Users" tecnico JOIN public."Users" actor ON actor."Id"=@usuario
              WHERE actor."IsActive"=1 AND (tecnico."RoleId"=2 OR (actor."RoleId"=1 AND tecnico."RoleId"=3)) AND tecnico."IsActive"=1
              AND (actor."RoleId"=1 OR (actor."RoleId"=3 AND EXISTS(SELECT 1 FROM public."CoordinatorTechnicians" c WHERE c."CoordinatorUserId"=@usuario AND c."TechnicianUserId"=tecnico."Id")))
              AND tecnico."Id"=ANY(@permitidos)
              ORDER BY tecnico."Name",tecnico."Id"
              """;
            AccesoTicketsPostgres.Parametro(cmd, "usuario", usuario); AccesoTicketsPostgres.Parametro(cmd, "permitidos", permitidos);
            await using var r = await cmd.ExecuteReaderAsync(lecturaCt); var lista = new List<RespuestaTecnico>();
            while (await r.ReadAsync(lecturaCt)) lista.Add(new(r.GetInt32(0), r.GetString(1), r.IsDBNull(2) ? null : r.GetInt32(2)));
            return lista;
        }, ct);
    }
    /// <summary>Asigna/reasigna únicamente equipo autorizado; no reabre ni modifica UUID y acepta reintento idéntico.</summary>
    public async Task<bool> Asignar(int usuario, int ticket, int tecnico, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct); await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
          UPDATE public."Tickets" t SET "TechnicianId"=@tecnico,"UpdatedAt"=now()
          WHERE t."Id"=@ticket AND (t."Status" NOT IN ('Resolved','Cancelled') OR t."TechnicianId"=@tecnico)
          AND EXISTS(SELECT 1 FROM public."Users" destino WHERE destino."Id"=@tecnico AND destino."IsActive"=1 AND (destino."RoleId"=2 OR (destino."RoleId"=3 AND (@tecnico=@usuario OR EXISTS(SELECT 1 FROM public."Users" WHERE "Id"=@usuario AND "RoleId"=1 AND "IsActive"=1)))))
          AND EXISTS(SELECT 1 FROM public."Users" actor WHERE actor."Id"=@usuario AND actor."IsActive"=1 AND (
            actor."RoleId"=1 OR (actor."RoleId"=3 AND
              (EXISTS(SELECT 1 FROM public."CoordinatorTechnicians" c WHERE c."CoordinatorUserId"=@usuario AND c."TechnicianUserId"=@tecnico) OR @tecnico=@usuario)
              AND (t."TechnicianId" IS NULL OR t."TechnicianId"=@usuario OR EXISTS(SELECT 1 FROM public."CoordinatorTechnicians" c WHERE c."CoordinatorUserId"=@usuario AND c."TechnicianUserId"=t."TechnicianId")))))
          """;
        AccesoTicketsPostgres.Parametro(cmd, "usuario", usuario); AccesoTicketsPostgres.Parametro(cmd, "ticket", ticket); AccesoTicketsPostgres.Parametro(cmd, "tecnico", tecnico);
        return await cmd.ExecuteNonQueryAsync(ct) == 1;
    }
}
