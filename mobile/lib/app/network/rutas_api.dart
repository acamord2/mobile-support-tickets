/// Centraliza los paths HTTP de endpoints existentes, separados de las rutas GetX.
/// Evita strings repetidos en consumidores y permite cambiar los contratos desde
/// un único archivo; no anticipa endpoints de funcionalidades todavía inexistentes.
abstract class RutasApi {
  static const healthDatabase = '/api/health/database';
  static const login = '/api/auth/login';
  static const me = '/api/auth/me';
}
