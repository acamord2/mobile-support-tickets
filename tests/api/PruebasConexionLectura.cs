using System.Data.Common;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.Http;
using Npgsql;
using Tickets.Api.Data.Connections;
using Tickets.Api.Services;

/// <summary>Pruebas optativas de conexiones SELECT reales; inyectan configuración exclusivamente al proceso de prueba.</summary>
internal static class PruebasConexionLectura
{
    public static async Task Ejecutar()
    {
        var archivo=Environment.GetEnvironmentVariable("PRUEBA_CONEXIONES_FILE") ?? throw new Exception("Falta configuración privada de prueba.");
        var baseConfig=new ConfigurationBuilder().AddJsonFile(archivo).Build();
        var escritura=baseConfig["ConnectionStrings:Escritura"]!;
        var lectura=baseConfig["ConnectionStrings:Lectura"]!;
        IConfiguration Config(string cadena)=>new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>
        {
            ["ConnectionStrings:Escritura"]=escritura,["ConnectionStrings:Lectura"]=cadena
        }).Build();
        var principal=new Conexion(Config(lectura),Options.Create(new ConfiguracionSecretsApi { LecturasEnPrimario=true }));
        await using(var cn=await principal.OpenConnectionAsync())
        {
            await using var cmd=cn.CreateCommand();cmd.CommandText="SELECT NOT pg_is_in_recovery()";
            Exigir((bool)(await cmd.ExecuteScalarAsync())!,"Escritura apunta a primario");
        }
        // Ejecutar también los SELECT completos actuales contra el primario con rol de consulta.
        // No se ejecuta ningún método de escritura; la API activa no recibe esta configuración.
        var tickets=new Tickets.Api.Data.AccesoTicketsPostgres(principal);
        await tickets.Sucursales(default); await tickets.Agenda(2,default);
        await new Tickets.Api.Data.AccesoEventosPostgres(principal).Listar(2,7,default);
        await new Tickets.Api.Data.AccesoSolicitudesPostgres(principal).Listar(2,true,default);
        await new Tickets.Api.Data.AccesoCoordinacionPostgres(principal).Tecnicos(2,default);
        async Task<bool> Consulta(DbConnection cn,DbTransaction tx,CancellationToken ct)
        {
            await using var cmd=cn.CreateCommand();cmd.Transaction=tx;
            cmd.CommandText="SELECT session_user='consultor_api' AND current_setting('transaction_read_only')='on' AND current_setting('transaction_isolation')='repeatable read' AND NOT pg_is_in_recovery()";
            return (bool)(await cmd.ExecuteScalarAsync(ct))!;
        }
        Exigir(await principal.EjecutarLecturaAsync(Consulta),"Selector primario conserva cuenta consultora y RR/RO");
        var caida=new NpgsqlConnectionStringBuilder(lectura){Host="127.0.0.1",Port=1}.ConnectionString;
        var fallback=new Conexion(Config(caida),Options.Create(new ConfiguracionSecretsApi()));
        var reloj=System.Diagnostics.Stopwatch.StartNew();
        Exigir(await fallback.EjecutarLecturaAsync(Consulta),"Standby simulado inaccesible: único fallback primario consultor");
        Exigir(reloj.Elapsed<TimeSpan.FromSeconds(9),"Fallback acotado");
        var sinFallback=new Conexion(Config(caida),Options.Create(new ConfiguracionSecretsApi { PermitirFallbackLectura=false }));
        try {await sinFallback.EjecutarLecturaAsync(Consulta);throw new Exception("Fallback desactivado ignorado");}
        catch(NpgsqlException e) when(e.IsTransient){}
        var contexto=new HttpContextAccessor{HttpContext=new DefaultHttpContext()};
        contexto.HttpContext.Request.Headers["X-Consistencia"]="inmediata";
        var inmediata=new Conexion(Config(caida),Options.Create(new ConfiguracionSecretsApi()),contexto);
        Exigir(await inmediata.EjecutarLecturaAsync(Consulta),"Consistencia inmediata elude standby y usa cuenta consultora primaria");
        using var cancelacion=new CancellationTokenSource();cancelacion.Cancel();
        try {await fallback.EjecutarLecturaAsync(Consulta,cancelacion.Token);throw new Exception("Cancelación ignorada");}
        catch(OperationCanceledException){}
        var secundaria=new Conexion(Config(lectura),Options.Create(new ConfiguracionSecretsApi()));
        Exigir(await secundaria.EjecutarLecturaAsync(async (cn,tx,ct) =>
        {
            await using var cmd=cn.CreateCommand(); cmd.Transaction=tx;
            cmd.CommandText="SELECT pg_is_in_recovery() AND session_user='consultor_api' AND current_setting('transaction_read_only')='on'";
            return (bool)(await cmd.ExecuteScalarAsync(ct))!;
        }),"Conexión real consultora al standby");
        Console.WriteLine("Conexiones SELECT: primario, cuenta consultora, RR/RO, selector, fallback acotado, cancelación e inmediata correctos. Standby real autorizado por SCRAM y solo lectura.");
    }
    private static void Exigir(bool ok,string mensaje){if(!ok)throw new Exception(mensaje);}
}
