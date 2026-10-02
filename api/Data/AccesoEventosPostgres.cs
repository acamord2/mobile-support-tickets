using System.Data.Common;
using Tickets.Api.Data.Connections;
using Tickets.Api.DTOs;
using Tickets.Api.Models;
namespace Tickets.Api.Data;

/// <summary>Persiste eventos propios inmutables y lee cronología mediante la conexión existente y parámetros.</summary>
public sealed class AccesoEventosPostgres(IConexion conexion)
{
    /// <summary>Inserta por UUID una sola vez; valida vínculo de foto/ticket y recupera el mismo Id en reintentos concurrentes.</summary>
    public async Task<int?> Guardar(int usuario, int ticket, SolicitudEvento s, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var tx = await cn.BeginTransactionAsync(ct);
        await using var cmd = cn.CreateCommand(); cmd.Transaction = tx;
        cmd.CommandText = """
            INSERT INTO public."TicketEvents" ("TicketId","EventType","Description","CreatedAt","UserId","ClientRequestId","PreviousScheduledAt","ScheduledAt","EvidenceId")
            SELECT @ticket,@tipo,@descripcion,@fecha,@usuario,@clave,@anterior,@programada,@evidencia
            WHERE EXISTS(SELECT 1 FROM public."Tickets" t WHERE t."Id"=@ticket AND t."Status" NOT IN ('Resolved','Cancelled') AND
            """ + " " + AccesoTicketsPostgres.Alcance + " " + """
            )
              AND (@tipo<>'CREADO' OR EXISTS(SELECT 1 FROM public."Tickets" WHERE "Id"=@ticket AND "ReporterUserId"=@usuario))
              AND (@evidencia IS NULL OR EXISTS(SELECT 1 FROM public."Evidences" WHERE "Id"=@evidencia AND "TicketId"=@ticket AND "PhotoBase64" IS NOT NULL))
            ON CONFLICT ("UserId","ClientRequestId") DO NOTHING
            """;
        Parametro(cmd, "ticket", ticket); Parametro(cmd, "usuario", usuario); Parametro(cmd, "tipo", s.EventType!.Value.ToString());
        Parametro(cmd, "descripcion", s.Description.Trim()); Parametro(cmd, "fecha", s.CreatedAt!.Value.UtcDateTime);
        Parametro(cmd, "clave", s.ClientRequestId); Parametro(cmd, "anterior", s.PreviousScheduledAt?.UtcDateTime, System.Data.DbType.DateTime);
        Parametro(cmd, "programada", s.ScheduledAt?.UtcDateTime, System.Data.DbType.DateTime);
        Parametro(cmd, "evidencia", s.EvidenceId, System.Data.DbType.Int32);
        await cmd.ExecuteNonQueryAsync(ct);
        cmd.CommandText = "SELECT \"Id\" FROM public.\"TicketEvents\" WHERE \"UserId\"=@usuario AND \"ClientRequestId\"=@clave AND \"TicketId\"=@ticket";
        var id = await cmd.ExecuteScalarAsync(ct);
        await tx.CommitAsync(ct); return id is int valor ? valor : null;
    }

    /// <summary>Lee solo eventos del ticket propio, ordenados por instante e Id y con autor identificado por FK.</summary>
    public async Task<List<RespuestaEvento>> Listar(int usuario, int ticket, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
            SELECT e."Id",e."TicketId",e."EventType",e."Description",e."CreatedAt",e."UserId",u."Name",e."ClientRequestId",e."PreviousScheduledAt",e."ScheduledAt",e."EvidenceId"
            FROM public."TicketEvents" e JOIN public."Tickets" t ON t."Id"=e."TicketId" JOIN public."Users" u ON u."Id"=e."UserId"
            WHERE e."TicketId"=@ticket AND
            """ + " " + AccesoTicketsPostgres.Alcance + " ORDER BY e.\"CreatedAt\",e.\"Id\"";
        Parametro(cmd, "usuario", usuario); Parametro(cmd, "ticket", ticket);
        await using var r = await cmd.ExecuteReaderAsync(ct); var lista = new List<RespuestaEvento>();
        while (await r.ReadAsync(ct)) lista.Add(new(r.GetInt32(0), r.GetInt32(1), Enum.Parse<TipoEventoTicket>(r.GetString(2)), r.GetString(3), r.GetDateTime(4), r.GetInt32(5), r.GetString(6), r.GetGuid(7), r.IsDBNull(8) ? null : r.GetDateTime(8), r.IsDBNull(9) ? null : r.GetDateTime(9), r.IsDBNull(10) ? null : r.GetInt32(10)));
        return lista;
    }

    /// <summary>Tipa también nulos para que PostgreSQL reciba fechas/IDs sin inferencias ambiguas.</summary>
    private static void Parametro(DbCommand cmd, string nombre, object? valor, System.Data.DbType? tipo = null)
    {
        var p = cmd.CreateParameter(); p.ParameterName = nombre; p.Value = valor ?? DBNull.Value;
        if (tipo is not null) p.DbType = tipo.Value; cmd.Parameters.Add(p);
    }
}
