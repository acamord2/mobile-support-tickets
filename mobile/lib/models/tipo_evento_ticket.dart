/// Centraliza tipos persistidos y enviados; las claves coinciden con PostgreSQL.
enum TipoEventoTicket {
  creado('CREADO'),
  programado('PROGRAMADO'),
  reprogramado('REPROGRAMADO'),
  enAtencion('EN_ATENCION'),
  seguimiento('SEGUIMIENTO'),
  resuelto('RESUELTO');

  final String clave;
  const TipoEventoTicket(this.clave);
}
