using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Tickets.Api.Data;
using Tickets.Api.Data.Connections;
using Tickets.Api.Models;
using Tickets.Api.Services;

// La API no instala ni migra la base externa.
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
// Todo acceso activo utiliza IConexion; EF Core permanece sin registrar.
builder.Services.AddScoped<IConexion, Conexion>();
builder.Services.AddScoped<IAccesoUsuarios, AccesoUsuariosPostgres>();
builder.Services.AddScoped<AccesoTicketsPostgres>();
builder.Services.AddScoped<AccesoEventosPostgres>();
builder.Services.AddScoped<AccesoCoordinacionPostgres>();
builder.Services.AddScoped<AccesoSolicitudesPostgres>();
builder.Services.AddScoped<IPasswordHasher<Usuario>, PasswordHasher<Usuario>>();
builder.Services.AddScoped<ServicioAutenticacion>();
builder.Services.AddScoped<IServicioSaludBaseDatos, ServicioSaludBaseDatos>();

ConfiguracionSecretsApi.Registrar(builder.Services, builder.Configuration);
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer();
builder.Services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<Microsoft.Extensions.Options.IOptions<OpcionesJwt>>((options, settings) =>
    {
        var jwt = settings.Value;
        // /me requiere los nombres originales de los claims.
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
// Swagger refleja los atributos de autorización de cada endpoint.
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
// Swagger y HTTP local se habilitan únicamente en Development.
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
