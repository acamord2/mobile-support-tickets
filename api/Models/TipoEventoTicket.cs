using System.Text.Json.Serialization;
namespace Tickets.Api.Models;

/// <summary>Define los tipos de atención y decisiones persistidos; el JSON usa las claves exactas de PostgreSQL.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<TipoEventoTicket>))]
public enum TipoEventoTicket { CREADO, PROGRAMADO, REPROGRAMADO, EN_ATENCION, SEGUIMIENTO, RESUELTO, ASIGNADO, REASIGNADO, SOLICITUD_RESOLUCION, SOLICITUD_CANCELACION, RESOLUCION_APROBADA, RESOLUCION_RECHAZADA, CANCELACION_APROBADA, CANCELACION_RECHAZADA, CANCELADO }
