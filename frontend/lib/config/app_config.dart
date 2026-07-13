/// Configuración central de la app — URL del backend Java real.
///
/// Local (móvil físico, misma WiFi):
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080
///
/// Emulador Android:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// Producción AWS EC2 (Java API):
///   flutter run --dart-define=API_BASE_URL=http://34.235.130.33:8005
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}
