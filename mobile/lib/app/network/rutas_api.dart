/// Centraliza los paths HTTP de endpoints existentes, separados de las rutas GetX.
/// Evita strings repetidos en consumidores y permite cambiar los contratos desde
/// un único archivo; no anticipa endpoints de funcionalidades todavía inexistentes.
abstract class RutasApi {
  static const tecnicos = '/api/technicians';
  static String asignacion(int ticket) => '/api/tickets/$ticket/assignment';
  static const healthDatabase = '/api/health/database';
  static const login = '/api/auth/login';
  static const me = '/api/auth/me';
  static const tickets = '/api/tickets';
  static const sucursales = '/api/branches';
  static String evidencia(int ticket) => '$tickets/$ticket/evidence';
  static String eventos(int ticket) => '$tickets/$ticket/events';
  static const solicitudes = '/api/ticket-status-requests';
  static String solicitarEstado(int ticket) =>
      '/api/tickets/$ticket/status-requests';
  static String revisarSolicitud(int id) => '$solicitudes/$id/review';
}
