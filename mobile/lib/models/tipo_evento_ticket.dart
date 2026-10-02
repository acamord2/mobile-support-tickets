/// Centraliza tipos persistidos y enviados; las claves coinciden con PostgreSQL.
enum TipoEventoTicket {
  creado('CREADO'),
  programado('PROGRAMADO'),
  reprogramado('REPROGRAMADO'),
  enAtencion('EN_ATENCION'),
  seguimiento('SEGUIMIENTO'),
  resuelto('RESUELTO'),
  asignado('ASIGNADO'),
  reasignado('REASIGNADO'),
  solicitudResolucion('SOLICITUD_RESOLUCION'),
  solicitudCancelacion('SOLICITUD_CANCELACION'),
  resolucionAprobada('RESOLUCION_APROBADA'),
  resolucionRechazada('RESOLUCION_RECHAZADA'),
  cancelacionAprobada('CANCELACION_APROBADA'),
  cancelacionRechazada('CANCELACION_RECHAZADA'),
  cancelado('CANCELADO');

  final String clave;
  const TipoEventoTicket(this.clave);
}
