import 'dart:math';
import '../models/prediction_result.dart';

class ApiService {
  final _random = Random();

  // Genera una lectura de sensores simulada (estado normal o caída)
  SensorSnapshot _generateSensorData({bool simulateFall = false}) {
    if (simulateFall) {
      // Valores típicos de una caída: aceleración alta, giroscopio alterado,
      // frecuencia cardíaca elevada por el impacto
      return SensorSnapshot(
        accelX: _randomRange(-18, 18),
        accelY: _randomRange(-18, 18),
        accelZ: _randomRange(-18, 18),
        gyroX: _randomRange(-500, 500),
        gyroY: _randomRange(-500, 500),
        gyroZ: _randomRange(-500, 500),
        heartRate: _randomRange(90, 130),
        roomTemp: _randomRange(18, 26),
        roomLight: _randomRange(50, 800),
      );
    } else {
      // Valores típicos en reposo o movimiento normal
      return SensorSnapshot(
        accelX: _randomRange(-2, 2),
        accelY: _randomRange(-2, 2),
        accelZ: _randomRange(8, 10), // ~gravedad
        gyroX: _randomRange(-10, 10),
        gyroY: _randomRange(-10, 10),
        gyroZ: _randomRange(-10, 10),
        heartRate: _randomRange(60, 85),
        roomTemp: _randomRange(18, 26),
        roomLight: _randomRange(50, 800),
      );
    }
  }

  // Lógica de clasificación basada en magnitudes del dataset mockeado
  bool _classify(SensorSnapshot s) {
    final accelMag = sqrt(s.accelX * s.accelX + s.accelY * s.accelY + s.accelZ * s.accelZ);
    final gyroMag = sqrt(s.gyroX * s.gyroX + s.gyroY * s.gyroY + s.gyroZ * s.gyroZ);
    return accelMag > 15 || gyroMag > 300;
  }

  /// Genera una lectura de sensores y devuelve el resultado de detección.
  /// [simulateFall] fuerza que los datos simulen una caída.
  Future<FallDetectionResult> analyze({bool simulateFall = false}) async {
    await Future.delayed(const Duration(milliseconds: 600)); // simula latencia

    final snapshot = _generateSensorData(simulateFall: simulateFall);
    final fallDetected = _classify(snapshot);
    final confidence = fallDetected
        ? _randomRange(0.80, 0.99)
        : _randomRange(0.85, 0.99);

    return FallDetectionResult(
      fallDetected: fallDetected,
      confidence: confidence,
      snapshot: snapshot,
      timestamp: DateTime.now(),
    );
  }

  /// Genera una lectura continua (para stream en tiempo real).
  Stream<SensorSnapshot> sensorStream() {
    return Stream.periodic(const Duration(seconds: 1), (_) {
      return _generateSensorData();
    });
  }

  double _randomRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }
}
