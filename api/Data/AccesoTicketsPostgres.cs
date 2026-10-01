using System.Data.Common;
using Tickets.Api.Data.Connections;
using Tickets.Api.DTOs;
namespace Tickets.Api.Data;

/// <summary>Centraliza consultas parametrizadas y alcance real por rol, sin confiar en filtros del teléfono.</summary>
public sealed class AccesoTicketsPostgres(IConexion conexion)
{
    /// <summary>Limita datos a reportante, técnico asignado o equipo del coordinador; administrador ve todos.</summary>
    internal const string Alcance = """
        EXISTS (SELECT 1 FROM public."Users" u WHERE u."Id"=@usuario AND u."IsActive"=1 AND (
          u."RoleId"=1 OR (u."RoleId"=4 AND t."ReporterUserId"=@usuario)
          OR (u."RoleId"=2 AND t."TechnicianId"=@usuario)
          OR (u."RoleId"=3 AND (t."TechnicianId" IS NULL OR EXISTS (
            SELECT 1 FROM public."CoordinatorTechnicians" c JOIN public."Users" tecnico ON tecnico."Id"=c."TechnicianUserId"
            WHERE c."CoordinatorUserId"=@usuario AND c."TechnicianUserId"=t."TechnicianId" AND tecnico."RoleId"=2 AND tecnico."IsActive"=1)))))
        """;

    /// <summary>Lee actividad actual, sin aceptar un JWT antiguo de una cuenta desactivada.</summary>
    public async Task<bool> Activo(int usuario, CancellationToken ct) => await Rol(usuario, ct) is > 0;

    /// <summary>Consulta el rol vigente en lugar de confiar exclusivamente en claims emitidos antes de un cambio.</summary>
    public async Task<int> Rol(int usuario, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = "SELECT \"RoleId\" FROM public.\"Users\" WHERE \"Id\"=@usuario AND \"IsActive\"=1";
        Parametro(cmd, "usuario", usuario);
        return await cmd.ExecuteScalarAsync(ct) is int rol ? rol : 0;
    }

    /// <summary>Valida acciones operativas únicamente para técnico asignado o administrador.</summary>
    public async Task<bool> PuedeOperar(int usuario, int ticket, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
          SELECT EXISTS(SELECT 1 FROM public."Tickets" t JOIN public."Users" u ON u."Id"=@usuario
          WHERE t."Id"=@ticket AND u."IsActive"=1 AND (u."RoleId"=1 OR (u."RoleId"=2 AND t."TechnicianId"=@usuario)))
          """;
        Parametro(cmd, "usuario", usuario); Parametro(cmd, "ticket", ticket);
        return (bool)(await cmd.ExecuteScalarAsync(ct))!;
    }

    /// <summary>Entrega catálogo real para formularios offline; no incorpora datos ficticios.</summary>
    public async Task<List<RespuestaSucursal>> Sucursales(CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = "SELECT \"Id\",\"Name\",\"Address\" FROM public.\"Branches\" ORDER BY \"Name\",\"Id\"";
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var datos = new List<RespuestaSucursal>();
        while (await r.ReadAsync(ct)) datos.Add(new(r.GetInt32(0), r.GetString(1), r.GetString(2)));
        return datos;
    }

    /// <summary>Lee tickets visibles y sus evidencias con el mismo alcance, antes de almacenarlos localmente.</summary>
    public async Task<List<RespuestaTicket>> Agenda(int usuario, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        var agenda = await Leer(cn, usuario, null, ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = "SELECT e.\"Id\",e.\"TicketId\",e.\"Description\",e.\"PhotoBase64\",e.\"CreatedAt\" FROM public.\"Evidences\" e JOIN public.\"Tickets\" t ON t.\"Id\"=e.\"TicketId\" WHERE " + Alcance + " ORDER BY e.\"CreatedAt\",e.\"Id\"";
        Parametro(cmd, "usuario", usuario);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var porId = agenda.ToDictionary(t => t.Id);
        while (await r.ReadAsync(ct))
            if (porId.TryGetValue(r.GetInt32(1), out var ticket))
                ticket.Evidences.Add(new(r.GetInt32(0), r.GetString(2), r.IsDBNull(3) ? null : r.GetString(3), r.GetDateTime(4)));
        return agenda;
    }

    /// <summary>Persiste reportante autenticado e identidad UUID global, independiente de cualquier asignación posterior.</summary>
    public async Task<RespuestaTicket?> Crear(int usuario, SolicitudTicket solicitud, CancellationToken ct)
    {
        var rol = await Rol(usuario, ct);
        if (rol is not (1 or 2 or 4)) return null;
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
            INSERT INTO public."Tickets" ("BranchId","TechnicianId","ReporterUserId","Title","Description","Status","CreatedAt","UpdatedAt","ScheduledAt","ClientRequestId")
            SELECT @sucursal,CASE WHEN @rol=2 THEN @usuario ELSE NULL END,@usuario,@titulo,@descripcion,'Pending',@creado,@actualizado,@fecha,@clave
            WHERE EXISTS(SELECT 1 FROM public."Branches" WHERE "Id"=@sucursal)
            ON CONFLICT ("ClientRequestId") DO NOTHING
            """;
        Parametro(cmd, "sucursal", solicitud.BranchId); Parametro(cmd, "usuario", usuario); Parametro(cmd, "rol", rol);
        Parametro(cmd, "titulo", solicitud.Title.Trim()); Parametro(cmd, "descripcion", solicitud.Description.Trim());
        Parametro(cmd, "fecha", solicitud.ScheduledAt.UtcDateTime); Parametro(cmd, "clave", solicitud.ClientRequestId);
        var creado = solicitud.CreatedAt ?? DateTimeOffset.UtcNow;
        Parametro(cmd, "creado", creado.UtcDateTime); Parametro(cmd, "actualizado", (solicitud.UpdatedAt ?? creado).UtcDateTime);
        await cmd.ExecuteNonQueryAsync(ct);
        return (await Leer(cn, usuario, solicitud.ClientRequestId, ct, creacionPropia: true)).SingleOrDefault();
    }

    /// <summary>Guarda evidencia solo en alcance técnico autorizado y deduplica reintentos bajo bloqueo del ticket.</summary>
    public async Task<int?> Evidencia(int usuario, int ticket, SolicitudEvidencia solicitud, CancellationToken ct)
    {
        if (!await PuedeOperar(usuario, ticket, ct)) return null;
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var tx = await cn.BeginTransactionAsync(ct);
        await using var cmd = cn.CreateCommand(); cmd.Transaction = tx;
        cmd.CommandText = """
          SELECT t."Status" FROM public."Tickets" t WHERE t."Id"=@ticket AND EXISTS(
            SELECT 1 FROM public."Users" u WHERE u."Id"=@usuario AND u."IsActive"=1
            AND (u."RoleId"=1 OR (u."RoleId"=2 AND t."TechnicianId"=@usuario))) FOR UPDATE
          """;
        Parametro(cmd, "ticket", ticket); Parametro(cmd, "usuario", usuario);
        if (await cmd.ExecuteScalarAsync(ct) is not string estado) return null;
        cmd.Parameters.Clear(); Parametro(cmd, "ticket", ticket); Parametro(cmd, "descripcion", solicitud.Description.Trim()); Parametro(cmd, "foto", solicitud.PhotoBase64);
        cmd.CommandText = "SELECT \"Id\" FROM public.\"Evidences\" WHERE \"TicketId\"=@ticket AND \"Description\"=@descripcion AND \"PhotoBase64\" IS NOT DISTINCT FROM @foto ORDER BY \"Id\" LIMIT 1";
        var previo = await cmd.ExecuteScalarAsync(ct);
        if (previo is not null) { await tx.CommitAsync(ct); return (int)previo; }
        if (estado == "Resolved") return null;
        cmd.CommandText = "INSERT INTO public.\"Evidences\" (\"TicketId\",\"Description\",\"PhotoBase64\",\"CreatedAt\") VALUES (@ticket,@descripcion,@foto,now()) RETURNING \"Id\"";
        var id = (int)(await cmd.ExecuteScalarAsync(ct))!;
        await tx.CommitAsync(ct); return id;
    }

    /// <summary>Actualiza sin reabrir resueltos; cambios de estado requieren técnico autorizado y seguimiento manual para resolver.</summary>
    public async Task<bool> Actualizar(int usuario, int id, SolicitudActualizarTicket s, CancellationToken ct)
    {
        var rol = await Rol(usuario, ct);
        if (rol is not (1 or 2 or 3)) return false;
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
          UPDATE public."Tickets" t SET "Title"=@titulo,"Description"=@descripcion,"Status"=@estado,"ScheduledAt"=@fecha,"UpdatedAt"=now()
          WHERE t."Id"=@id AND
          """ + " " + Alcance + " " + """
          AND (t."Status"<>'Resolved' OR (t."Status"=@estado AND t."Title"=@titulo AND t."Description"=@descripcion AND t."ScheduledAt"=@fecha))
          AND (t."Status"=@estado OR (@rol IN (1,2) AND (@rol=1 OR t."TechnicianId"=@usuario)
            AND ((t."Status"='Pending' AND @estado IN ('InProgress','Resolved')) OR (t."Status"='InProgress' AND @estado='Resolved'))))
          AND (@estado<>'Resolved' OR EXISTS(SELECT 1 FROM public."TicketEvents" e WHERE e."TicketId"=t."Id" AND e."EventType"='SEGUIMIENTO'))
          """;
        Parametro(cmd, "usuario", usuario); Parametro(cmd, "rol", rol); Parametro(cmd, "id", id);
        Parametro(cmd, "titulo", s.Title.Trim()); Parametro(cmd, "descripcion", s.Description.Trim());
        Parametro(cmd, "estado", s.Status); Parametro(cmd, "fecha", s.ScheduledAt.UtcDateTime);
        return await cmd.ExecuteNonQueryAsync(ct) == 1;
    }

    /// <summary>Consulta campos explícitos de las tablas actuales, incluyendo técnico nullable y reportante histórico nullable.</summary>
    private static async Task<List<RespuestaTicket>> Leer(DbConnection cn, int usuario, Guid? clave, CancellationToken ct, bool creacionPropia = false)
    {
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
          SELECT t."Id",t."BranchId",t."TechnicianId",t."Title",t."Description",t."Status",t."CreatedAt",t."UpdatedAt",t."ScheduledAt",t."ClientRequestId",b."Name",b."Address",t."ReporterUserId"
          FROM public."Tickets" t JOIN public."Branches" b ON b."Id"=t."BranchId" WHERE
          """ + " " + (creacionPropia ? "t.\"ReporterUserId\"=@usuario" : Alcance) + (clave is null ? "" : " AND t.\"ClientRequestId\"=@clave") + " ORDER BY t.\"ScheduledAt\",t.\"CreatedAt\",t.\"Id\"";
        Parametro(cmd, "usuario", usuario); if (clave is not null) Parametro(cmd, "clave", clave.Value);
        await using var r = await cmd.ExecuteReaderAsync(ct); var lista = new List<RespuestaTicket>();
        while (await r.ReadAsync(ct)) lista.Add(new(r.GetInt32(0), r.GetInt32(1), r.IsDBNull(2) ? null : r.GetInt32(2), r.GetString(3), r.GetString(4), r.GetString(5), r.GetDateTime(6), r.GetDateTime(7), r.GetDateTime(8), r.IsDBNull(9) ? null : r.GetGuid(9), r.GetString(10), r.GetString(11)) { ReporterUserId = r.IsDBNull(12) ? null : r.GetInt32(12) });
        return lista;
    }

    /// <summary>Enlaza parámetros comunes, sin interpolar valores recibidos ni imprimir información sensible.</summary>
    internal static void Parametro(DbCommand cmd, string nombre, object? valor)
    {
        var p = cmd.CreateParameter(); p.ParameterName = nombre; p.Value = valor ?? DBNull.Value;
        if (valor is null) p.DbType = System.Data.DbType.String;
        cmd.Parameters.Add(p);
    }
}
