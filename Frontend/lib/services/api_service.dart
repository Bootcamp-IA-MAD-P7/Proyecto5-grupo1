import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';

class ApiService {
  static const String _baseUrl = 'https://proyecto5-grupo1.onrender.com';

  // Cambia a false para usar el backend real en Render
  static const bool _useMock = false;

  final _random = Random();

  // --- API REAL ---

  Future<FallDetectionResult> analyzeRemote(SensorSnapshot snapshot) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'accel_x': snapshot.accelX,
        'accel_y': snapshot.accelY,
        'accel_z': snapshot.accelZ,
        'gyro_x': snapshot.gyroX,
        'gyro_y': snapshot.gyroY,
        'gyro_z': snapshot.gyroZ,
        'heart_rate': snapshot.heartRate,
        'room_temp': snapshot.roomTemp,
        'room_light': snapshot.roomLight,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return FallDetectionResult(
        fallDetected: json['fall_detected'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        snapshot: snapshot,
        timestamp: DateTime.now(),
      );
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  // --- MOCK (TODO: eliminar cuando sensores reales + modelo ML estén integrados) ---
  // Datos generados con Random — solo para desarrollo offline. No usar para entrenamiento.

  SensorSnapshot _generateSensorData({bool simulateFall = false}) {
    if (simulateFall) {
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
      return SensorSnapshot(
        accelX: _randomRange(-2, 2),
        accelY: _randomRange(-2, 2),
        accelZ: _randomRange(8, 10),
        gyroX: _randomRange(-10, 10),
        gyroY: _randomRange(-10, 10),
        gyroZ: _randomRange(-10, 10),
        heartRate: _randomRange(60, 85),
        roomTemp: _randomRange(18, 26),
        roomLight: _randomRange(50, 800),
      );
    }
  }

  bool _classify(SensorSnapshot s) {
    final accelMag = sqrt(s.accelX * s.accelX + s.accelY * s.accelY + s.accelZ * s.accelZ);
    final gyroMag = sqrt(s.gyroX * s.gyroX + s.gyroY * s.gyroY + s.gyroZ * s.gyroZ);
    return accelMag > 15 || gyroMag > 300;
  }

  // --- INTERFAZ PÚBLICA ---

  /// Analiza una lectura de sensores.
  /// Usa el backend real o el mock según [_useMock].
  Future<FallDetectionResult> analyze({bool simulateFall = false}) async {
    final snapshot = _generateSensorData(simulateFall: simulateFall);

    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
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

    return analyzeRemote(snapshot);
  }

  /// Stream de lecturas de sensores cada segundo.
  Stream<SensorSnapshot> sensorStream() {
    return Stream.periodic(const Duration(seconds: 1), (_) {
      return _generateSensorData();
    });
  }

  double _randomRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }
}
