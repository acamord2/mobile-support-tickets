using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Tickets.Api.Data;
using Tickets.Api.Models;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Tickets.Api.DTOs;
using Tickets.Api.Services;

// Comprueba reglas sin dependencias de pruebas adicionales. El modo real requiere
// autorización y conserva exactamente un ticket y una evidencia de validación.
if(ValidacionEvidencia.Valida(new(){Description="Prueba",PhotoBase64="data:image/jpeg;base64,AA==",Mime="image/jpeg"})) throw new Exception("Prefijo aceptado.");
if(ValidacionEvidencia.Valida(new(){Description="Prueba",PhotoBase64="???",Mime="image/jpeg"})) throw new Exception("Base64 inválido aceptado.");
if(ValidacionEvidencia.Valida(new(){Description="Prueba",PhotoBase64=Convert.ToBase64String(new byte[ValidacionEvidencia.MaximoBytes+1]),Mime="image/jpeg"})) throw new Exception("Tamaño excesivo aceptado.");
if(ValidacionEvidencia.Valida(new(){Description="Prueba",PhotoBase64="AA==",Mime="image/png"})) throw new Exception("MIME inválido aceptado.");
if(!ValidacionEvidencia.Valida(new(){Description="Prueba"})) throw new Exception("Descripción válida rechazada.");
Console.WriteLine("Validación API: prefijo, Base64, MIME, bytes decodificados y evidencia descriptiva correctos.");
var hasher=new PasswordHasher<Usuario>();
var inactivo=new Usuario { Id=1,Username="prueba",Name="Prueba",RoleId=2,Role="Técnico",IsActive=0 };
inactivo.PasswordHash=hasher.HashPassword(inactivo,"password-de-prueba");
var opciones=Options.Create(new OpcionesJwt { Key=Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(48)),Issuer="pruebas",Audience="pruebas",ExpirationMinutes=5 });
var autenticacion=new ServicioAutenticacion(new AccesoUsuarioSimulado(inactivo),hasher,opciones);
if(await autenticacion.LoginAsync(new SolicitudLogin { Username="prueba",Password="password-de-prueba" },default) is not null) throw new Exception("Usuario inactivo autenticado.");
Console.WriteLine("Usuario inactivo con contraseña correcta: autenticación rechazada sin modificar datos.");
if(!args.Contains("--real")) return;
var raiz=Path.GetFullPath(Path.Combine(AppContext.BaseDirectory,"../../../../../"));
var demo=File.ReadAllText(Path.Combine(raiz,"database/PostgreSQL/v1/DATOS_PRUEBA.sql"));
var match=System.Text.RegularExpressions.Regex.Match(demo,@"\*\*([^ /]+) / ([^*]+\*)\*\*");
if(!match.Success) throw new Exception("Credencial demo no localizada en documento autorizado.");
using var http=new HttpClient { BaseAddress=new Uri(Environment.GetEnvironmentVariable("API_TEST_URL")??"http://localhost:5263") };
if((await http.GetAsync("/api/health/database")).StatusCode!=HttpStatusCode.OK) throw new Exception("Health inválido.");
var login=await http.PostAsJsonAsync("/api/auth/login",new {username=match.Groups[1].Value,password=match.Groups[2].Value});
if(login.StatusCode!=HttpStatusCode.OK) throw new Exception("Login inválido.");
var json=JsonDocument.Parse(await login.Content.ReadAsStringAsync()).RootElement;
var usuario=json.GetProperty("user").GetProperty("id").GetInt32();
if(json.GetProperty("user").GetProperty("roleId").GetInt32()!=2) throw new Exception("Rol inválido.");
http.DefaultRequestHeaders.Authorization=new("Bearer",json.GetProperty("token").GetString());
if((await http.GetAsync("/api/auth/me")).StatusCode!=HttpStatusCode.OK) throw new Exception("Me inválido.");
var ramas=await http.GetFromJsonAsync<JsonElement>("/api/branches");
var clave=Guid.NewGuid();
var solicitud=new {branchId=ramas[0].GetProperty("id").GetInt32(),title="Prueba técnica: idempotencia concurrente",description="Registro autorizado de validación; cinco solicitudes y un reintento deben conservar un solo Id.",scheduledAt=DateTimeOffset.UtcNow,clientRequestId=clave};
var respuestas=await Task.WhenAll(Enumerable.Range(0,5).Select(_=>http.PostAsJsonAsync("/api/tickets",solicitud)));
var ids=new List<int>();
foreach(var r in respuestas) { if(r.StatusCode!=HttpStatusCode.OK) throw new Exception("Creación inválida."); ids.Add(JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("id").GetInt32()); }
var reintento=await http.PostAsJsonAsync("/api/tickets",solicitud);
ids.Add(JsonDocument.Parse(await reintento.Content.ReadAsStringAsync()).RootElement.GetProperty("id").GetInt32());
if(ids.Distinct().Count()!=1) throw new Exception("Ticket duplicado.");
var agenda=await http.GetFromJsonAsync<JsonElement>("/api/tickets");
if(agenda.EnumerateArray().Any(t=>t.GetProperty("technicianId").GetInt32()!=usuario)) throw new Exception("Agenda ajena.");
if(agenda.EnumerateArray().Count(t=>t.GetProperty("clientRequestId").ValueKind==JsonValueKind.String && t.GetProperty("clientRequestId").GetGuid()==clave)!=1) throw new Exception("Clave duplicada en agenda.");
using var anonimo=new HttpClient { BaseAddress=http.BaseAddress };
if((await anonimo.GetAsync("/api/tickets")).StatusCode!=HttpStatusCode.Unauthorized) throw new Exception("Protección inválida.");
var evidencia=await http.PostAsJsonAsync($"/api/tickets/{ids[0]}/evidence",new {description="Prueba autorizada de evidencia descriptiva idempotente"});
if(evidencia.StatusCode!=HttpStatusCode.OK) throw new Exception("Evidencia inválida.");
var e1=JsonDocument.Parse(await evidencia.Content.ReadAsStringAsync()).RootElement.GetProperty("id").GetInt32();
var e2=await http.PostAsJsonAsync($"/api/tickets/{ids[0]}/evidence",new {description="Prueba autorizada de evidencia descriptiva idempotente"});
if(JsonDocument.Parse(await e2.Content.ReadAsStringAsync()).RootElement.GetProperty("id").GetInt32()!=e1) throw new Exception("Evidencia duplicada.");
var invalida=await http.PostAsJsonAsync($"/api/tickets/{ids[0]}/evidence",new {description="Inválida",photoBase64="data:image/jpeg;base64,AA==",mime="image/jpeg"});
if(invalida.StatusCode!=HttpStatusCode.BadRequest) throw new Exception("Base64 inválido aceptado.");
var swagger=await http.GetFromJsonAsync<JsonElement>("/swagger/v1/swagger.json");
var ruta=swagger.GetProperty("paths").GetProperty("/api/tickets");
if(!ruta.TryGetProperty("get",out _)||!ruta.TryGetProperty("post",out _)) throw new Exception("Swagger incompleto.");
Console.WriteLine($"Health/login/me/agenda/sucursales/Swagger: 200. Anónimo: 401. Cinco creaciones concurrentes más reintento: un ticket Id {ids[0]}. Evidencia reintentada: un Id {e1}. Base64 inválido: 400. Los dos registros autorizados se conservaron.");

/// <summary>Entrega una identidad interna ficticia para comprobar inactividad sin modificar cuentas PostgreSQL ni depender de red.</summary>
internal sealed class AccesoUsuarioSimulado(Usuario usuario):IAccesoUsuarios
{
    /// <summary>Devuelve el usuario preparado exclusivamente para validar la regla de autenticación en memoria.</summary>
    public Task<Usuario?> GetByUsernameAsync(string username,CancellationToken cancellationToken=default)=>Task.FromResult<Usuario?>(usuario);
}