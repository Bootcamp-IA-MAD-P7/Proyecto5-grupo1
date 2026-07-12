/// Shared SL-14 telemetry window contract.
///
/// Keep these constants aligned with `contracts/window_contract.json`, the
/// cross-stack source of truth used by ML, inference and Flutter.
final class WindowContract {
  const WindowContract._();

  static const int durationMs = 2500;
  static const int sampleRateHz = 50;
  static const double overlapRatio = 0.5;
  static const int hopMs = 1250;
  static const int samplesPerSignal = 125;

  static const List<String> requiredSampleKeys = [
    'accX',
    'accY',
    'accZ',
    'gyroX',
    'gyroY',
    'gyroZ',
  ];

  static const List<String> optionalContextKeys = [
    'heartRate',
    'roomTemp',
    'roomLight',
  ];
}
