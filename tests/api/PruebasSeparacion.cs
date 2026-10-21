using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Identity;
using Tickets.Api.Models;
using System.Data;
using System.Data.Common;
using System.Collections;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Tickets.Api.Data;
using Tickets.Api.Data.Connections;
using Tickets.Api.Controllers.Tickets;
using Tickets.Api.Controllers.Auth;
using Tickets.Api.DTOs;
using Tickets.Api.Services;

/// <summary>Comprueba destinos y transacciones mediante ADO.NET simulado; nunca escribe datos de negocio.</summary>
internal static class PruebasSeparacion
{
    public static async Task Ejecutar()
    {
        var f = new ConexionObservada();
        var tickets = new AccesoTicketsPostgres(f);
        await tickets.Sucursales(default);
        await tickets.Agenda(2, default);
        await new AccesoEventosPostgres(f).Listar(2, 7, default);
        await new AccesoSolicitudesPostgres(f).Listar(2, true, default);
        await new AccesoCoordinacionPostgres(f).Tecnicos(2, default);
        Exigir(f.Lecturas == 5, "Cinco operaciones replicables");
        Exigir(f.Ordenes.Where(x => x.Lectura).All(x => x.Transaccion), "Todos los SELECT replicables comparten transacción");
        Exigir(f.Ordenes.Where(x => x.Lectura && x.Sql.Contains("@permitidos")).All(x => x.Permitidos), "Alcance primario parametrizado en réplica");
        var agenda = f.Ordenes.Where(x => x.Lectura && (x.Sql.Contains("b.\"Address\"") || x.Sql.Contains("e.\"PhotoBase64\""))).ToList();
        Exigir(agenda.Count >= 2, "Agenda y evidencias en lectura");
        Console.WriteLine("Rutas: sucursales/agenda/eventos/solicitudes/técnicos -> consulta; alcance -> primario.");
        var anteriores=f.Lecturas;
        await tickets.Activo(2,default); await tickets.Rol(2,default); await tickets.PuedeOperar(2,7,default);
        await new AccesoUsuariosPostgres(f).GetByUsernameAsync("prueba",default);
        await tickets.Crear(2,new SolicitudTicket { BranchId=1,Title="Solo memoria",Description="Solo memoria",ClientRequestId=Guid.NewGuid() },default);
        await tickets.Actualizar(2,7,new SolicitudActualizarTicket { Title="Solo memoria",Description="Solo memoria",Status="Pending" },default);
        await tickets.Evidencia(2,7,new SolicitudEvidencia { Description="Solo memoria" },default);
        await new AccesoCoordinacionPostgres(f).Asignar(2,7,2,default);
        await new AccesoEventosPostgres(f).Guardar(2,7,new SolicitudEvento { EventType=Tickets.Api.Models.TipoEventoTicket.SEGUIMIENTO,Description="Solo memoria",CreatedAt=DateTimeOffset.UtcNow,ClientRequestId=Guid.NewGuid() },default);
        await new AccesoSolicitudesPostgres(f).Crear(2,7,new SolicitudEstadoTicket { Type="SOLICITUD_RESOLUCION",CreatedAt=DateTimeOffset.UtcNow,ClientRequestId=Guid.NewGuid(),EventClientRequestId=Guid.NewGuid() },default);
        await new AccesoSolicitudesPostgres(f).Revisar(2,7,new RevisionSolicitudEstado { Status="RECHAZADA",ReviewedAt=DateTimeOffset.UtcNow,DecisionClientRequestId=Guid.NewGuid() },default);
        Exigir(f.Lecturas==anteriores,"Autenticación, permisos, escrituras, bloqueos y lectura después de INSERT permanecen en primario");
        Exigir(f.Ordenes.Where(x=>x.Sql.Contains("FOR UPDATE") || x.Sql.Contains("INSERT") || x.Sql.Contains("UPDATE public")).All(x=>!x.Lectura),"Sin SQL de escritura en réplica");
        Exigir(f.Ordenes.Any(x=>!x.Lectura && x.Sql.Contains("@clave") && x.Sql.Contains("b.\"Address\"")),"Respuesta de creación leída en conexión primaria");
        Console.WriteLine("Rutas: login/me/permisos y todas las escrituras -> primario; sin reintentos de escritura.");
        var sucursales=new ControladorSucursales(tickets);
        sucursales.ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=new ClaimsPrincipal(new ClaimsIdentity(new[]{new Claim("sub","2")},"prueba")) } };
        Exigir(await sucursales.Obtener(default) is OkObjectResult,"Endpoint sucursales devuelve200");
        var identidad=new ControladorIdentidad(new AccesoUsuariosPostgres(f));
        identidad.ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext() };
        Exigir((await identidad.Me(default)).Result is UnauthorizedResult,"Me sin identidad devuelve401");
        f.FalloPrimario=true;
        try { await tickets.Agenda(2,default); throw new Exception("Se permitió autorización desde réplica"); }
        catch(TimeoutException) { }
        Console.WriteLine("Endpoints:200/401 correctos; primaria inaccesible no autoriza desde réplica (sin modo degradado).");
        await EndpointsHttp();
    }

    /// <summary>Ejecuta controllers y middleware reales en un servidor efímero con ADO.NET simulado y autenticación exclusiva del test.</summary>
    private static async Task EndpointsHttp()
    {
        var f=new ConexionObservada();
        var builder=WebApplication.CreateBuilder(new WebApplicationOptions { EnvironmentName="Testing", Args=[] });
        builder.WebHost.UseUrls("http://127.0.0.1:0");builder.Logging.ClearProviders();
        builder.Services.AddSingleton<IConexion>(f);
        builder.Services.AddHttpContextAccessor();
        builder.Services.AddSingleton(TimeProvider.System);
        builder.Services.AddSingleton<ContinuidadConsultas>();
        builder.Services.AddScoped<AccesoTicketsPostgres>();builder.Services.AddScoped<AccesoEventosPostgres>();
        builder.Services.AddScoped<AccesoCoordinacionPostgres>();builder.Services.AddScoped<AccesoSolicitudesPostgres>();
        builder.Services.AddScoped<IAccesoUsuarios,AccesoUsuariosPostgres>();
        builder.Services.AddScoped<ServicioAutenticacion>();builder.Services.AddScoped<IPasswordHasher<Usuario>,PasswordHasher<Usuario>>();
        builder.Services.AddSingleton<IOptions<OpcionesJwt>>(Options.Create(new OpcionesJwt { Key=new string('A',48),Issuer="pruebas",Audience="pruebas",ExpirationMinutes=5 }));
        builder.Services.AddScoped<IServicioSaludBaseDatos,ServicioSaludBaseDatos>();
        builder.Services.AddAuthentication("Prueba").AddScheme<AuthenticationSchemeOptions,IdentidadPrueba>("Prueba",_=>{});
        builder.Services.AddAuthorization();builder.Services.AddControllers().AddApplicationPart(typeof(ControladorAgenda).Assembly);
        await using var app=builder.Build();
        app.UseMiddleware<LimiteSolicitudBaseDatos>();app.UseAuthentication();app.UseAuthorization();app.MapControllers();
        await app.StartAsync();
        try
        {
            var direccion=app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.Single();
            using var http=new HttpClient { BaseAddress=new Uri(direccion),Timeout=TimeSpan.FromSeconds(12) };
            Exigir((await http.GetAsync("/api/tickets")).StatusCode==HttpStatusCode.Unauthorized,"HTTP401 sin identidad");
            Exigir((await http.GetAsync("/api/health/database")).StatusCode==HttpStatusCode.OK,"HTTP200 health primario");
            http.DefaultRequestHeaders.Add("X-Prueba","autorizada");
            foreach(var ruta in new[]{"/api/branches","/api/tickets","/api/tickets/7/events","/api/ticket-status-requests?pendingOnly=false"})
                Exigir((await http.GetAsync(ruta)).StatusCode==HttpStatusCode.OK,"HTTP200 listado autorizado");
            Exigir((await http.GetAsync("/api/technicians")).StatusCode==HttpStatusCode.Forbidden,"HTTP403 rol técnico fuera de coordinación");
            Exigir((await http.GetAsync("/api/auth/me")).StatusCode==HttpStatusCode.Unauthorized,"HTTP401 identidad no encontrada");
            var antes=f.Lecturas;f.FalloPrimario=true;
            var caida=await http.GetAsync("/api/tickets");
            Exigir(caida.StatusCode==HttpStatusCode.ServiceUnavailable && caida.Headers.RetryAfter!=null && f.Lecturas==antes,"HTTP503 sin autorizar desde réplica");
            f.FalloPrimario=false;
            http.DefaultRequestHeaders.Authorization=new("Bearer","credencial-ficticia-test");
            Exigir((await http.GetAsync("/api/tickets")).StatusCode==HttpStatusCode.OK,"Preparación primaria del alcance temporal");
            f.FalloPrimario=true;
            var temporal=await http.GetAsync("/api/tickets");
            Exigir(temporal.StatusCode==HttpStatusCode.OK && temporal.Headers.GetValues("X-Autorizacion").Single()=="temporal-no-confirmada","GET degradado mantiene autorización temporal etiquetada");
            using var carga=new StringContent(System.Text.Json.JsonSerializer.Serialize(new { branchId=1,title="Solo memoria",description="Solo memoria",clientRequestId=Guid.NewGuid() }),System.Text.Encoding.UTF8,"application/json");
            Exigir((await http.PostAsync("/api/tickets",carga)).StatusCode==HttpStatusCode.ServiceUnavailable,"POST degradado rechazado503");
            Exigir((await http.GetAsync("/api/auth/me")).StatusCode==HttpStatusCode.ServiceUnavailable,"Me no usa autorización degradada");
            http.DefaultRequestHeaders.Authorization=new("Bearer","otra-identidad-test");
            Exigir((await http.GetAsync("/api/tickets")).StatusCode==HttpStatusCode.ServiceUnavailable,"JWT sin validación primaria previa rechazado503");
            Console.WriteLine("HTTP degradado aislado: GET200 con etiqueta temporal; POST/me/JWT nuevo503, sin bases detenidas.");
            Console.WriteLine("HTTP real aislado: listados/health200, anónimo401, rol403, /me401 y fallo primario503; sin tocar API desplegada.");
        }
        finally { await app.StopAsync(); }
    }

    /// <summary>Identidad ficticia disponible solo dentro del servidor de prueba; no modifica el JWT de la aplicación.</summary>
    private sealed class IdentidadPrueba(IOptionsMonitor<AuthenticationSchemeOptions> opciones,ILoggerFactory logger,UrlEncoder encoder):AuthenticationHandler<AuthenticationSchemeOptions>(opciones,logger,encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if(Request.Headers["X-Prueba"]!="autorizada")return Task.FromResult(AuthenticateResult.NoResult());
            var identidad=new ClaimsIdentity(new[]{new Claim("sub","2"),new Claim("username","prueba"),new Claim("name","Prueba")},Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identidad),Scheme.Name)));
        }
    }

    /// <summary>Falla con una descripción pública, sin volcar SQL ni credenciales.</summary>
    private static void Exigir(bool valor,string mensaje) { if(!valor)throw new Exception(mensaje); }

    private sealed class ConexionObservada:IConexion
    {
        public int Lecturas; public bool FalloPrimario;
        public List<(bool Lectura,bool Transaccion,string Sql,bool Permitidos)> Ordenes=[];
        public Task<DbConnection> OpenConnectionAsync(CancellationToken ct=default)
        {
            if(FalloPrimario)throw new TimeoutException();
            return Task.FromResult<DbConnection>(new ConexionFalsa(this,false));
        }
        public async Task<T> EjecutarLecturaAsync<T>(Func<DbConnection,DbTransaction,CancellationToken,Task<T>> leer,CancellationToken ct=default)
        {
            Lecturas++;
            await using var cn=new ConexionFalsa(this,true);
            await using var tx=cn.BeginTransaction(IsolationLevel.RepeatableRead);
            return await leer(cn,tx,ct);
        }
    }

    private sealed class ConexionFalsa(ConexionObservada registro,bool lectura):DbConnection
    {
        [System.Diagnostics.CodeAnalysis.AllowNull]
        public override string ConnectionString {get;set;}="";
        public override string Database=>"memoria"; public override string DataSource=>lectura?"secundaria":"primaria";
        public override string ServerVersion=>"17"; public override ConnectionState State=>ConnectionState.Open;
        public override void ChangeDatabase(string s){} public override void Close(){} public override void Open(){}
        protected override DbTransaction BeginDbTransaction(IsolationLevel i)=>new TransaccionFalsa(this,i);
        protected override DbCommand CreateDbCommand()=>new ComandoFalso(this,registro,lectura);
    }
    private sealed class TransaccionFalsa(DbConnection cn,IsolationLevel nivel):DbTransaction
    {
        public override IsolationLevel IsolationLevel=>nivel; protected override DbConnection DbConnection=>cn;
        public override void Commit(){} public override void Rollback(){}
    }
    private sealed class ComandoFalso(DbConnection cn,ConexionObservada registro,bool lectura):DbCommand
    {
        private readonly Parametros lista=new();
        [System.Diagnostics.CodeAnalysis.AllowNull]
        public override string CommandText {get;set;}=""; public override int CommandTimeout {get;set;}
        public override CommandType CommandType {get;set;}=CommandType.Text; public override bool DesignTimeVisible {get;set;}
        public override UpdateRowSource UpdatedRowSource {get;set;}
        protected override DbConnection? DbConnection {get;set;}=cn;
        protected override DbTransaction? DbTransaction {get;set;}
        protected override DbParameterCollection DbParameterCollection=>lista;
        public override void Cancel(){} public override void Prepare(){}
        protected override DbParameter CreateDbParameter()=>new Npgsql.NpgsqlParameter();
        private void Registrar()=>registro.Ordenes.Add((lectura,DbTransaction!=null,CommandText,!CommandText.Contains("@permitidos") || lista.Cast<DbParameter>().Any(p=>p.ParameterName=="permitidos" && p.Value is int[])));
        public override int ExecuteNonQuery(){Registrar();return 1;}
        public override object? ExecuteScalar()
        {
            Registrar();
            if(CommandText.StartsWith("SELECT \"RoleId\""))return 2;
            if(CommandText.StartsWith("SELECT EXISTS"))return true;
            if(CommandText.Contains("SELECT t.\"Status\""))return "Pending";
            if(CommandText.StartsWith("INSERT"))return 7;
            if(CommandText.StartsWith("SELECT \"TicketId\""))return null;
            return null;
        }
        protected override DbDataReader ExecuteDbDataReader(CommandBehavior behavior)
        {
            Registrar(); var tabla=new DataTable();
            if(!lectura && CommandText.TrimStart().StartsWith("SELECT t.\"Id\" FROM")){tabla.Columns.Add("Id",typeof(int));tabla.Rows.Add(7);}
            return tabla.CreateDataReader();
        }
    }
    private sealed class Parametros:DbParameterCollection
    {
        private readonly List<DbParameter> lista=[];
        public override int Count=>lista.Count; public override object SyncRoot=>this;
        public override int Add(object v){lista.Add((DbParameter)v);return lista.Count-1;}
        public override void AddRange(Array v){foreach(var x in v)Add(x!);}
        public override void Clear()=>lista.Clear(); public override bool Contains(object v)=>lista.Contains((DbParameter)v);
        public override bool Contains(string n)=>IndexOf(n)>=0; public override void CopyTo(Array a,int i)=>((ICollection)lista).CopyTo(a,i);
        public override IEnumerator GetEnumerator()=>lista.GetEnumerator(); public override int IndexOf(object v)=>lista.IndexOf((DbParameter)v);
        public override int IndexOf(string n)=>lista.FindIndex(p=>p.ParameterName==n);
        public override void Insert(int i,object v)=>lista.Insert(i,(DbParameter)v); public override void Remove(object v)=>lista.Remove((DbParameter)v);
        public override void RemoveAt(int i)=>lista.RemoveAt(i); public override void RemoveAt(string n)=>RemoveAt(IndexOf(n));
        protected override DbParameter GetParameter(int i)=>lista[i]; protected override DbParameter GetParameter(string n)=>lista[IndexOf(n)];
        protected override void SetParameter(int i,DbParameter p)=>lista[i]=p; protected override void SetParameter(string n,DbParameter p){var i=IndexOf(n);if(i<0)lista.Add(p);else lista[i]=p;}
    }
}
