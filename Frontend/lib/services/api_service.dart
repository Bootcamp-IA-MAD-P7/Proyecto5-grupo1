import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/prediction_result.dart';

class ApiService {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _demoMonitoredId = 'local-demo-monitored';
  static const double _demoSampleRateHz = 50;

  // false = API local/docker o remota vía --dart-define=API_BASE_URL=...
  static const bool _useMock = false;

  final _random = Random();
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // --- API REAL ---

  Future<FallDetectionResult> analyzeRemote(SensorSnapshot snapshot) async {
    final now = DateTime.now();
    final response = await _client.post(
      Uri.parse('$_baseUrl/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'windowId': 'demo-${now.microsecondsSinceEpoch}',
        'monitoredId': _demoMonitoredId,
        'sampleRateHz': _demoSampleRateHz,
        'samples': {
          'accX': [snapshot.accelX],
          'accY': [snapshot.accelY],
          'accZ': [snapshot.accelZ],
          'gyroX': [snapshot.gyroX],
          'gyroY': [snapshot.gyroY],
          'gyroZ': [snapshot.gyroZ],
        },
        // Valores sintéticos temporales para el probador local. La tarea SL-23
        // sustituirá esta lectura aislada por ventanas y datos reales.
        'subjectFeatures': {
          'age': 65,
          'sex': 'OTHER',
          'weightKg': 70.0,
          'heightCm': 170.0,
        },
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return FallDetectionResult(
        fallDetected: json['fallDetected'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        snapshot: snapshot,
        timestamp: now,
      );
    }

    throw Exception(
      'Error del servidor: ${response.statusCode} ${response.body}',
    );
  }

  // --- MOCK ---
  // Datos generados para desarrollo offline. No usar para entrenamiento.

  SensorSnapshot _generateSensorData({bool simulateFall = false}) {
    if (simulateFall) {
      return SensorSnapshot(
        // Superan los umbrales para que "Simular caída" sea determinista.
        accelX: 20.0,
        accelY: _randomRange(-18, 18),
        accelZ: _randomRange(-18, 18),
        gyroX: 400.0,
        gyroY: _randomRange(-500, 500),
        gyroZ: _randomRange(-500, 500),
        heartRate: _randomRange(90, 130),
        roomTemp: _randomRange(18, 26),
        roomLight: _randomRange(50, 800),
      );
    }

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

  bool _classify(SensorSnapshot snapshot) {
    final accelMagnitude = sqrt(
      snapshot.accelX * snapshot.accelX +
          snapshot.accelY * snapshot.accelY +
          snapshot.accelZ * snapshot.accelZ,
    );
    final gyroMagnitude = sqrt(
      snapshot.gyroX * snapshot.gyroX +
          snapshot.gyroY * snapshot.gyroY +
          snapshot.gyroZ * snapshot.gyroZ,
    );
    return accelMagnitude > 15 || gyroMagnitude > 300;
  }

  // --- INTERFAZ PÚBLICA ---

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

  Stream<SensorSnapshot> sensorStream() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) => _generateSensorData(),
    );
  }

  double _randomRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }
}
