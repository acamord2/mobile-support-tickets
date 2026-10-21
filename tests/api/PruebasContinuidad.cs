using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Tickets.Api.Services;

/// <summary>Simula fallos sin detener bases; comprueba TTL, identidad, revocación y prohibición de escritura degradada.</summary>
internal static class PruebasContinuidad
{
    public static async Task Ejecutar()
    {
        var contexto=new HttpContextAccessor();var reloj=new Reloj();var servicio=new ContinuidadConsultas(contexto,reloj);
        void Peticion(string token="A",string metodo="GET",string ruta="/api/tickets")
        {
            contexto.HttpContext=new DefaultHttpContext();var h=contexto.HttpContext;
            h.Request.Method=metodo;h.Request.Path=ruta;h.Request.Headers.Authorization="Bearer "+token;
            h.User=new ClaimsPrincipal(new ClaimsIdentity(new[]{new Claim("sub","2")},"prueba"));
        }
        Task<int> Caida()=>throw new TimeoutException();
        Task<int[]> CaidaIds()=>throw new TimeoutException();
        Peticion();await servicio.ObtenerAsync("rol",2,()=>Task.FromResult(2),default);
        await servicio.ObtenerAsync("tickets",2,()=>Task.FromResult(new[]{7}),default);
        Peticion();if(await servicio.ObtenerAsync("rol",2,Caida,default)!=2)throw new Exception("Rol temporal perdido");
        var ids=await servicio.ObtenerAsync("tickets",2,CaidaIds,default);
        if(!ids.SequenceEqual(new[]{7}) || contexto.HttpContext!.Response.Headers["X-Autorizacion"]!="temporal-no-confirmada")throw new Exception("Alcance o etiqueta degradada incorrectos");
        foreach(var caso in new[]{("B","GET","/api/tickets"),("A","POST","/api/tickets"),("A","GET","/api/auth/me"),("A","POST","/api/auth/login")})
        {
            Peticion(caso.Item1,caso.Item2,caso.Item3);
            try{await servicio.ObtenerAsync("rol",2,Caida,default);throw new Exception("Se autorizó identidad/operación no elegible");}catch(TimeoutException){}
        }
        reloj.Avanzar(121);Peticion();
        try{await servicio.ObtenerAsync("rol",2,Caida,default);throw new Exception("TTL expirado aceptado");}catch(TimeoutException){}
        Peticion();await servicio.ObtenerAsync("rol",2,()=>Task.FromResult(2),default);
        await servicio.ObtenerAsync("tickets",2,()=>Task.FromResult(new[]{7}),default);
        Peticion();if(await servicio.ObtenerAsync("rol",2,()=>Task.FromResult(0),default)!=0)throw new Exception("Revocación ignorada");
        Peticion();try{await servicio.ObtenerAsync("tickets",2,CaidaIds,default);throw new Exception("Revocación dejó alcance en caché");}catch(TimeoutException){}
        Console.WriteLine("Continuidad simulada: TTL120s, caché por JWT, alcance limitado, etiqueta temporal, sin login/me/escritura y revocación confirmada correctos.");
    }
    private sealed class Reloj:TimeProvider
    {
        private DateTimeOffset ahora=DateTimeOffset.UtcNow;
        public override DateTimeOffset GetUtcNow()=>ahora;
        public void Avanzar(int segundos)=>ahora=ahora.AddSeconds(segundos);
    }
}
