/// Centraliza nombre y versión de la base privada de la aplicación.
/// Las migraciones futuras deben aumentar versión y conservar datos existentes.
abstract class ConfiguracionSqlite {
  static const nombre = 'incidencias_tecnicas.db';
  static const version = 6;
}
