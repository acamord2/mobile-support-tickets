using System.Text.Json.Serialization;
namespace Tickets.Api.Models;

/// <summary>Define los seis tipos persistidos; el JSON usa las claves exactas de PostgreSQL.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<TipoEventoTicket>))]
public enum TipoEventoTicket { CREADO, PROGRAMADO, REPROGRAMADO, EN_ATENCION, SEGUIMIENTO, RESUELTO, ASIGNADO, REASIGNADO }
