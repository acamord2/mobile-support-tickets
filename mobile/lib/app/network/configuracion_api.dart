/// API_BASE_URL se establece con --dart-define; el valor predeterminado permite que Android Emulator alcance la API del equipo mediante su dirección especial.
abstract class ConfiguracionApi {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5263',
  );
  static const timeout = Duration(seconds: 15);
}
