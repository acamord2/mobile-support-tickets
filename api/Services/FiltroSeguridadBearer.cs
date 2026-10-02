using Microsoft.AspNetCore.Authorization;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace Tickets.Api.Services;

/// <summary>Describe en Swagger la protección JWT de las operaciones existentes.</summary>
public class FiltroSeguridadBearer : IOperationFilter
{
    /// <summary>Combina atributos del método y de su clase para reflejar la protección real del endpoint; solo modifica la descripción OpenAPI, no autentica solicitudes.</summary>
    /// <param name="operation">Operación OpenAPI que se está describiendo.</param>
    /// <param name="context">Metadatos del endpoint y documento que contiene el esquema Bearer.</param>
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        var attributes = context.MethodInfo.GetCustomAttributes(true)
            .Concat(context.MethodInfo.DeclaringType?.GetCustomAttributes(true) ?? []);
        if (attributes.OfType<AllowAnonymousAttribute>().Any()
            || !attributes.OfType<AuthorizeAttribute>().Any())
        {
            return;
        }

        operation.Security =
        [
            new OpenApiSecurityRequirement
            {
                [new OpenApiSecuritySchemeReference("Bearer", context.Document)] = []
            }
        ];
    }
}
