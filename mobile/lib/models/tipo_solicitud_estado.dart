/// Mantiene las claves comunes de SQLite, HTTP y PostgreSQL y sus textos públicos.
enum TipoSolicitudEstado {
  resolucion('SOLICITUD_RESOLUCION', 'Resolución'),
  cancelacion('SOLICITUD_CANCELACION', 'Cancelación');

  final String clave, texto;
  const TipoSolicitudEstado(this.clave, this.texto);
}

/// Distingue una decisión pendiente de sus resultados sin confundirla con el estado del ticket.
enum EstadoSolicitud {
  pendiente('PENDIENTE'),
  aprobada('APROBADA'),
  rechazada('RECHAZADA');

  final String clave;
  const EstadoSolicitud(this.clave);
}
