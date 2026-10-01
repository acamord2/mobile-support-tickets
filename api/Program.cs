using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Tickets.Api.Data;
using Tickets.Api.Data.Connections;
using Tickets.Api.Models;
using Tickets.Api.Services;

// El arranque solo configura HTTP y servicios. PostgreSQL debe existir previamente;
// no se ejecutan scripts, migraciones, seeds ni comprobaciones que modifiquen la BD.
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
// DI selecciona PostgreSQL una sola vez mediante el contrato común de conexión.
// EF Core permanece disponible, pero sin registro activo ni conexiones paralelas:
// las lecturas y health actuales utilizan exclusivamente IConexion.
builder.Services.AddScoped<IConexion, Conexion>();
builder.Services.AddScoped<IAccesoUsuarios, AccesoUsuariosPostgres>();
builder.Services.AddScoped<AccesoTicketsPostgres>();
builder.Services.AddScoped<IPasswordHasher<Usuario>, PasswordHasher<Usuario>>();
builder.Services.AddScoped<ServicioAutenticacion>();
builder.Services.AddScoped<IServicioSaludBaseDatos, ServicioSaludBaseDatos>();

// Las opciones se validan al iniciar para detectar configuración JWT incompleta
// antes de atender solicitudes; no contienen credenciales PostgreSQL hardcodeadas.
builder.Services.AddOptions<OpcionesJwt>()
    .Bind(builder.Configuration.GetSection("Jwt"))
    .ValidateDataAnnotations()
    .Validate(options => Encoding.UTF8.GetByteCount(options.Key) >= 32, "Jwt:Key debe tener al menos 32 bytes.")
    .ValidateOnStart();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer();
builder.Services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<Microsoft.Extensions.Options.IOptions<OpcionesJwt>>((options, settings) =>
    {
        var jwt = settings.Value;
        // Se conservan los nombres originales de claims para que /me lea sub,
        // username y name sin depender de conversiones implícitas del middleware.
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
            ClockSkew = TimeSpan.Zero
        };
    });
builder.Services.AddAuthorization();
// La descripción OpenAPI reutiliza los atributos de autorización de endpoints
// para ofrecer Bearer en Swagger sin duplicar decisiones de seguridad.
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Tickets API", Version = "v1" });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Introduce solamente el JWT obtenido en /api/auth/login."
    });
    options.OperationFilter<FiltroSeguridadBearer>();
});

var app = builder.Build();
// Swagger y HTTP local sirven para revisar la infraestructura en desarrollo.
// Fuera de ese entorno se conserva la redirección HTTPS y no se publica Swagger.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseHttpsRedirection();
}

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
