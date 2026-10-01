using System.ComponentModel.DataAnnotations;
namespace Tickets.Api.DTOs;
/// <summary>Recibe únicamente el técnico destino; autor y alcance proceden del usuario autenticado.</summary>
public sealed class SolicitudAsignacion { [Range(1, int.MaxValue)] public int TechnicianId { get; set; } }
