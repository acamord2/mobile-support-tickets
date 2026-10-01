using System.Data.Common;
using Tickets.Api.Data.Connections;
using Tickets.Api.DTOs;
namespace Tickets.Api.Data;
/// <summary>Consulta agenda y guarda tickets/evidencias con SQL parametrizado; encapsula PostgreSQL fuera de controllers y conserva garantías concurrentes de BD.</summary>
public sealed class AccesoTicketsPostgres(IConexion conexion)
{
    /// <summary>Comprueba actividad actual para impedir el uso remoto de JWT emitidos antes de una desactivación; no altera la sesión local.</summary>
    public async Task<bool> Activo(int usuario, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = "SELECT EXISTS(SELECT 1 FROM public.\"Users\" WHERE \"Id\"=@usuario AND \"IsActive\"=1)";
        Parametro(cmd,"usuario",usuario);
        return (bool)(await cmd.ExecuteScalarAsync(ct))!;
    }
    /// <summary>Lee sucursales reales de la base para descargar a SQLite, sin hardcodearlas en Flutter.</summary>
    public async Task<List<RespuestaSucursal>> Sucursales(CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = "SELECT \"Id\",\"Name\",\"Address\" FROM public.\"Branches\" ORDER BY \"Name\",\"Id\"";
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var datos = new List<RespuestaSucursal>();
        while (await r.ReadAsync(ct)) datos.Add(new(r.GetInt32(0),r.GetString(1),r.GetString(2)));
        return datos;
    }
    /// <summary>Filtra la vista de agenda por identidad autenticada para no consultar tickets ajenos.</summary>
    public async Task<List<RespuestaTicket>> Agenda(int usuario, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        var agenda = await Leer(cn,usuario,null,ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
            SELECT e."Id",e."TicketId",e."Description",e."PhotoBase64",e."CreatedAt"
            FROM public."Evidences" e JOIN public."Tickets" t ON t."Id"=e."TicketId"
            WHERE t."TechnicianId"=@usuario ORDER BY e."CreatedAt",e."Id"
            """;
        Parametro(cmd,"usuario",usuario);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var porId = agenda.ToDictionary(t => t.Id);
        while (await r.ReadAsync(ct))
            if (porId.TryGetValue(r.GetInt32(1),out var ticket))
                ticket.Evidences.Add(new(r.GetInt32(0),r.GetString(2),r.IsDBNull(3)?null:r.GetString(3),r.GetDateTime(4)));
        return agenda;
    }
    /// <summary>Inserta con ON CONFLICT y lee en un comando posterior; la restricción protege concurrencia y el segundo snapshot recupera el mismo Id ante reintentos.</summary>
    public async Task<RespuestaTicket?> Crear(int usuario, SolicitudTicket solicitud, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
            INSERT INTO public."Tickets" ("BranchId","TechnicianId","Title","Description","Status","CreatedAt","UpdatedAt","ScheduledAt","ClientRequestId")
            SELECT @sucursal,@usuario,@titulo,@descripcion,'Pending',@creado,@actualizado,@fecha,@clave
            WHERE EXISTS(SELECT 1 FROM public."Branches" WHERE "Id"=@sucursal)
            ON CONFLICT ("TechnicianId","ClientRequestId") DO NOTHING;
            """;
        Parametro(cmd,"sucursal",solicitud.BranchId); Parametro(cmd,"usuario",usuario);
        Parametro(cmd,"titulo",solicitud.Title.Trim()); Parametro(cmd,"descripcion",solicitud.Description.Trim());
        Parametro(cmd,"fecha",solicitud.ScheduledAt.UtcDateTime); Parametro(cmd,"clave",solicitud.ClientRequestId);
        var creado = solicitud.CreatedAt ?? DateTimeOffset.UtcNow;
        Parametro(cmd,"creado",creado.UtcDateTime);
        Parametro(cmd,"actualizado",(solicitud.UpdatedAt ?? creado).UtcDateTime);
        await cmd.ExecuteNonQueryAsync(ct);
        return (await Leer(cn,usuario,solicitud.ClientRequestId,ct)).SingleOrDefault();
    }
    /// <summary>Bloquea el ticket autorizado durante la inserción para colapsar reintentos de evidencia idéntica sin columnas extra; devuelve null para tickets ajenos.</summary>
    public async Task<int?> Evidencia(int usuario, int ticket, SolicitudEvidencia solicitud, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var tx = await cn.BeginTransactionAsync(ct);
        await using var cmd = cn.CreateCommand(); cmd.Transaction = tx;
        cmd.CommandText = "SELECT \"Id\" FROM public.\"Tickets\" WHERE \"Id\"=@ticket AND \"TechnicianId\"=@usuario FOR UPDATE";
        Parametro(cmd,"ticket",ticket); Parametro(cmd,"usuario",usuario);
        if (await cmd.ExecuteScalarAsync(ct) is null) return null;
        cmd.Parameters.Clear(); Parametro(cmd,"ticket",ticket);
        Parametro(cmd,"descripcion",solicitud.Description.Trim()); Parametro(cmd,"foto",solicitud.PhotoBase64);
        cmd.CommandText = """
            SELECT "Id" FROM public."Evidences" WHERE "TicketId"=@ticket AND "Description"=@descripcion
            AND "PhotoBase64" IS NOT DISTINCT FROM @foto ORDER BY "Id" LIMIT 1
            """;
        var previo = await cmd.ExecuteScalarAsync(ct);
        if (previo is not null) { await tx.CommitAsync(ct); return (int)previo; }
        cmd.CommandText = """
            INSERT INTO public."Evidences" ("TicketId","Description","PhotoBase64","CreatedAt")
            VALUES (@ticket,@descripcion,@foto,now()) RETURNING "Id"
            """;
        var id = (int)(await cmd.ExecuteScalarAsync(ct))!;
        await tx.CommitAsync(ct); return id;
    }
    /// <summary>Actualiza solo campos editables del propietario; PUT repetido conserva la misma identidad y programación sin crear filas.</summary>
    public async Task<bool> Actualizar(int usuario,int id,SolicitudActualizarTicket solicitud,CancellationToken ct)
    {
        await using var cn=await conexion.OpenConnectionAsync(ct);
        await using var cmd=cn.CreateCommand();
        cmd.CommandText="""
            UPDATE public."Tickets" SET "Title"=@titulo,"Description"=@descripcion,"Status"=@estado,
            "ScheduledAt"=@fecha,"UpdatedAt"=now() WHERE "Id"=@id AND "TechnicianId"=@usuario
            """;
        Parametro(cmd,"titulo",solicitud.Title.Trim()); Parametro(cmd,"descripcion",solicitud.Description.Trim());
        Parametro(cmd,"estado",solicitud.Status); Parametro(cmd,"fecha",solicitud.ScheduledAt.UtcDateTime);
        Parametro(cmd,"id",id); Parametro(cmd,"usuario",usuario);
        return await cmd.ExecuteNonQueryAsync(ct)==1;
    }
    /// <summary>Materializa la vista en DTOs públicos y ordena por programación, manteniendo SQL específico en acceso a datos.</summary>
    private static async Task<List<RespuestaTicket>> Leer(DbConnection cn,int usuario,Guid? clave,CancellationToken ct)
    {
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = "SELECT * FROM public.agenda_tickets WHERE \"TechnicianId\"=@usuario" + (clave is null ? "" : " AND \"ClientRequestId\"=@clave") + " ORDER BY \"ScheduledAt\",\"CreatedAt\",\"Id\"";
        Parametro(cmd,"usuario",usuario); if(clave is not null) Parametro(cmd,"clave",clave.Value);
        await using var r = await cmd.ExecuteReaderAsync(ct); var lista = new List<RespuestaTicket>();
        while(await r.ReadAsync(ct)) lista.Add(new(r.GetInt32(0),r.GetInt32(1),r.GetInt32(2),r.GetString(3),r.GetString(4),r.GetString(5),r.GetDateTime(6),r.GetDateTime(7),r.GetDateTime(8),r.IsDBNull(9)?null:r.GetGuid(9),r.GetString(10),r.GetString(11)));
        return lista;
    }
    /// <summary>Enlaza valores por parámetros comunes y tipa explícitamente nulos de texto para evitar inferencias del proveedor.</summary>
    private static void Parametro(DbCommand cmd,string nombre,object? valor)
    {
        var p = cmd.CreateParameter(); p.ParameterName=nombre; p.Value=valor??DBNull.Value;
        if(valor is null) p.DbType=System.Data.DbType.String;
        cmd.Parameters.Add(p);
    }
}
