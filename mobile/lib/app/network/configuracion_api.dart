/// Define la API accesible por LAN desde el teléfono físico para conectar la app.
/// --dart-define=API_BASE_URL permite elegir otra dirección al compilar sin editar
/// este archivo; el valor predeterminado corresponde al equipo de desarrollo.
abstract class ConfiguracionApi {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.104:5263',
  );
  static const timeout = Duration(seconds: 15);
}
