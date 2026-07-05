/// Configuración central de la app — una sola fuente para URLs de API.
///
/// Local (móvil físico, misma WiFi):
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
///
/// Emulador Android:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///
/// Legacy Render (TODO: eliminar al migrar a AWS):
///   https://proyecto5-grupo1.onrender.com
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
