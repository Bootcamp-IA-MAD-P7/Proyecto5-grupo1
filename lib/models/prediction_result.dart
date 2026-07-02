class SensorSnapshot {
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double heartRate;   // ppm
  final double roomTemp;    // °C
  final double roomLight;   // lux

  SensorSnapshot({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.heartRate,
    required this.roomTemp,
    required this.roomLight,
  });
}

class FallDetectionResult {
  final bool fallDetected;
  final double confidence;      // 0.0 - 1.0
  final SensorSnapshot snapshot;
  final DateTime timestamp;

  FallDetectionResult({
    required this.fallDetected,
    required this.confidence,
    required this.snapshot,
    required this.timestamp,
  });
}
