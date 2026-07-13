/// Configuración central de la app — URLs de API y modo mock.
///
/// Local (móvil físico, misma WiFi):
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080
///
/// Emulador Android:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// Producción AWS EC2 (Java API):
///   flutter run --dart-define=API_BASE_URL=http://34.235.130.33:8005
///
/// Desarrollo offline (mocks en memoria):
///   flutter run --dart-define=USE_MOCK=true
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// `false` por defecto — producto contra backend real (T2.18).
  /// Tests unitarios de mocks pasan `useMock: true` al constructor del servicio.
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );
}
