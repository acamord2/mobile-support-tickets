using System.Data.Common;
using Tickets.Api.Data.Connections;
using Tickets.Api.DTOs;
using Tickets.Api.Models;
namespace Tickets.Api.Data;

/// <summary>Guarda solicitudes y revisiones mediante bloqueos del ticket y transacciones;
/// mantiene workflow e historial coherentes sin nuevas capas ni SQL en controllers.</summary>
public sealed class AccesoSolicitudesPostgres(IConexion conexion)
{
    /// <summary>Lista solicitudes públicas del alcance real del actor; pendientes por defecto para revisión.</summary>
    public async Task<List<RespuestaSolicitudEstado>> Listar(int usuario, bool pendientes, CancellationToken ct)
    {
        await using var cn = await conexion.OpenConnectionAsync(ct);
        await using var cmd = cn.CreateCommand();
        cmd.CommandText = """
          SELECT s."Id",s."TicketId",s."RequesterUserId",autor."Name",s."Type",s."Reason",s."Status",s."CreatedAt",
            s."ReviewedByUserId",revisor."Name",s."ReviewedAt",s."ClientRequestId",t."Title"
          FROM public."TicketStatusRequests" s JOIN public."Tickets" t ON t."Id"=s."TicketId"
          JOIN public."Users" autor ON autor."Id"=s."RequesterUserId"
          LEFT JOIN public."Users" revisor ON revisor."Id"=s."ReviewedByUserId"
          WHERE (@pendientes=false OR s."Status"='PENDIENTE') AND
          """ + " " + AccesoTicketsPostgres.Alcance + " ORDER BY s.\"CreatedAt\",s.\"Id\"";
        AccesoTicketsPostgres.Parametro(cmd,"usuario",usuario);
        AccesoTicketsPostgres.Parametro(cmd,"pendientes",pendientes);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        var lista = new List<RespuestaSolicitudEstado>();
        while (await r.ReadAsync(ct)) lista.Add(new(r.GetInt32(0),r.GetInt32(1),r.GetInt32(2),r.GetString(3),r.GetString(4),
            r.IsDBNull(5)?null:r.GetString(5),r.GetString(6),r.GetDateTime(7),r.IsDBNull(8)?null:r.GetInt32(8),
            r.IsDBNull(9)?null:r.GetString(9),r.IsDBNull(10)?null:r.GetDateTime(10),r.GetGuid(11),r.GetString(12)));
        return lista;
    }

    /// <summary>Serializa por ticket para evitar pendientes equivalentes concurrentes; reintentos UUID retornan el mismo Id.</summary>
    public async Task<int?> Crear(int usuario,int ticket,SolicitudEstadoTicket s,CancellationToken ct)
    {
        await using var cn=await conexion.OpenConnectionAsync(ct);
        await using var tx=await cn.BeginTransactionAsync(ct);
        await using var cmd=cn.CreateCommand(); cmd.Transaction=tx;
        if (await Bloquear(cmd,usuario,ticket,ct) is not string estado) return null;
        cmd.CommandText="SELECT \"Id\" FROM public.\"TicketStatusRequests\" WHERE \"ClientRequestId\"=@clave AND \"TicketId\"=@ticket AND \"RequesterUserId\"=@usuario AND \"Type\"=@tipo";
        Parametros(cmd,("clave",s.ClientRequestId),("ticket",ticket),("usuario",usuario),("tipo",s.Type));
        if (await cmd.ExecuteScalarAsync(ct) is int previo) { await tx.CommitAsync(ct); return previo; }
        if (estado is "Resolved" or "Cancelled") return null;
        cmd.CommandText="SELECT EXISTS(SELECT 1 FROM public.\"Users\" u JOIN public.\"Tickets\" t ON t.\"Id\"=@ticket WHERE u.\"Id\"=@usuario AND u.\"IsActive\"=1 AND (u.\"RoleId\"=1 OR (u.\"RoleId\"=4 AND t.\"ReporterUserId\"=@usuario) OR (u.\"RoleId\" IN (2,3) AND t.\"TechnicianId\"=@usuario)))";
        Parametros(cmd,("ticket",ticket),("usuario",usuario));
        if (!(bool)(await cmd.ExecuteScalarAsync(ct))!) return null;
        cmd.CommandText="SELECT EXISTS(SELECT 1 FROM public.\"TicketStatusRequests\" WHERE \"TicketId\"=@ticket AND \"Type\"=@tipo AND \"Status\"='PENDIENTE')";
        Parametros(cmd,("ticket",ticket),("tipo",s.Type));
        if ((bool)(await cmd.ExecuteScalarAsync(ct))!) return null;
        cmd.CommandText="INSERT INTO public.\"TicketStatusRequests\" (\"TicketId\",\"RequesterUserId\",\"Type\",\"Reason\",\"Status\",\"CreatedAt\",\"ClientRequestId\") VALUES (@ticket,@usuario,@tipo,@motivo,'PENDIENTE',@fecha,@clave) ON CONFLICT (\"ClientRequestId\") DO NOTHING RETURNING \"Id\"";
        Parametros(cmd,("ticket",ticket),("usuario",usuario),("tipo",s.Type),("motivo",s.Reason?.Trim()),("fecha",s.CreatedAt.UtcDateTime),("clave",s.ClientRequestId));
        if (await cmd.ExecuteScalarAsync(ct) is not int id) return null;
        await Evento(cmd,ticket,usuario,s.Type,$"Solicitud #{id}: {s.Reason?.Trim() ?? "Sin comentario"}",s.CreatedAt.UtcDateTime,s.EventClientRequestId,ct);
        await tx.CommitAsync(ct); return id;
    }

    /// <summary>Revalida coordinador/administrador bajo bloqueo y decide una vez; ticket, revisión y eventos se confirman juntos.</summary>
    public async Task<int?> Revisar(int usuario,int id,RevisionSolicitudEstado s,CancellationToken ct)
    {
        await using var cn=await conexion.OpenConnectionAsync(ct);
        await using var tx=await cn.BeginTransactionAsync(ct);
        await using var cmd=cn.CreateCommand(); cmd.Transaction=tx;
        cmd.CommandText="SELECT \"TicketId\" FROM public.\"TicketStatusRequests\" WHERE \"Id\"=@id";
        Parametros(cmd,("id",id));
        if (await cmd.ExecuteScalarAsync(ct) is not int ticket) return null;
        if (await Bloquear(cmd,usuario,ticket,ct) is not string estadoTicket) return null;
        cmd.CommandText="SELECT EXISTS(SELECT 1 FROM public.\"Users\" WHERE \"Id\"=@usuario AND \"IsActive\"=1 AND \"RoleId\" IN (1,3))";
        Parametros(cmd,("usuario",usuario));
        if (!(bool)(await cmd.ExecuteScalarAsync(ct))!) return null;
        cmd.CommandText="SELECT \"Type\",\"Status\",\"RequesterUserId\",\"ReviewedByUserId\" FROM public.\"TicketStatusRequests\" WHERE \"Id\"=@id FOR UPDATE";
        Parametros(cmd,("id",id));
        string tipo,estado; int solicitante; int? revisor;
        await using (var r=await cmd.ExecuteReaderAsync(ct))
        {
            if (!await r.ReadAsync(ct)) return null;
            tipo=r.GetString(0); estado=r.GetString(1); solicitante=r.GetInt32(2); revisor=r.IsDBNull(3)?null:r.GetInt32(3);
        }
        if (estado!=TipoSolicitudEstado.Pendiente)
        {
            if (estado!=s.Status || revisor!=usuario) return null;
            await tx.CommitAsync(ct); return id;
        }
        var aprobar=s.Status==TipoSolicitudEstado.Aprobada;
        if (aprobar && estadoTicket is "Resolved" or "Cancelled") return null;
        cmd.CommandText="UPDATE public.\"TicketStatusRequests\" SET \"Status\"=@estado,\"ReviewedByUserId\"=@usuario,\"ReviewedAt\"=@fecha WHERE \"Id\"=@id";
        Parametros(cmd,("estado",s.Status),("usuario",usuario),("fecha",s.ReviewedAt.UtcDateTime),("id",id));
        await cmd.ExecuteNonQueryAsync(ct);
        var resolucion=tipo==TipoSolicitudEstado.Resolucion;
        var evento=resolucion ? (aprobar?"RESOLUCION_APROBADA":"RESOLUCION_RECHAZADA") : (aprobar?"CANCELACION_APROBADA":"CANCELACION_RECHAZADA");
        var descripcion=$"Solicitud #{id}, solicitante #{solicitante}, revisor #{usuario}: {s.Status}";
        await Evento(cmd,ticket,usuario,evento,descripcion,s.ReviewedAt.UtcDateTime,s.DecisionClientRequestId,ct);
        if (aprobar)
        {
            cmd.CommandText="UPDATE public.\"Tickets\" SET \"Status\"=@estado,\"UpdatedAt\"=now() WHERE \"Id\"=@ticket";
            Parametros(cmd,("estado",resolucion?"Resolved":"Cancelled"),("ticket",ticket));
            await cmd.ExecuteNonQueryAsync(ct);
            await Evento(cmd,ticket,usuario,resolucion?"RESUELTO":"CANCELADO",descripcion,s.ReviewedAt.UtcDateTime,s.FinalClientRequestId!.Value,ct);
        }
        await tx.CommitAsync(ct); return id;
    }

    /// <summary>Bloquea primero el ticket bajo el alcance vigente para serializar creación y revisión sin exponer datos ajenos.</summary>
    private static async Task<string?> Bloquear(DbCommand cmd,int usuario,int ticket,CancellationToken ct)
    {
        cmd.CommandText="SELECT t.\"Status\" FROM public.\"Tickets\" t WHERE t.\"Id\"=@ticket AND "+AccesoTicketsPostgres.Alcance+" FOR UPDATE";
        Parametros(cmd,("usuario",usuario),("ticket",ticket));
        return await cmd.ExecuteScalarAsync(ct) as string;
    }

    /// <summary>Inserta el historial dentro de la transacción del workflow, verificando que una clave no represente otro evento.</summary>
    private static async Task Evento(DbCommand cmd,int ticket,int usuario,string tipo,string descripcion,DateTime fecha,Guid clave,CancellationToken ct)
    {
        cmd.CommandText="INSERT INTO public.\"TicketEvents\" (\"TicketId\",\"EventType\",\"Description\",\"CreatedAt\",\"UserId\",\"ClientRequestId\") VALUES (@ticket,@tipo,@descripcion,@fecha,@usuario,@clave) ON CONFLICT (\"UserId\",\"ClientRequestId\") DO NOTHING";
        Parametros(cmd,("ticket",ticket),("tipo",tipo),("descripcion",descripcion),("fecha",fecha),("usuario",usuario),("clave",clave));
        await cmd.ExecuteNonQueryAsync(ct);
        cmd.CommandText="SELECT EXISTS(SELECT 1 FROM public.\"TicketEvents\" WHERE \"UserId\"=@usuario AND \"ClientRequestId\"=@clave AND \"TicketId\"=@ticket AND \"EventType\"=@tipo)";
        if (!(bool)(await cmd.ExecuteScalarAsync(ct))!) throw new InvalidOperationException("Identidad de evento incompatible.");
    }

    /// <summary>Reutiliza el enlace parametrizado existente y tipa los nulos de motivo; nunca interpola entradas.</summary>
    private static void Parametros(DbCommand cmd,params (string nombre,object? valor)[] datos)
    {
        cmd.Parameters.Clear();
        foreach (var (nombre,valor) in datos) AccesoTicketsPostgres.Parametro(cmd,nombre,valor);
    }
}
