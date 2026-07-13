import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_headers.dart';
import 'exceptions.dart';

/// Resultado de clasificación de una ventana (spec §6.3)
class WindowPrediction {
  final String windowId;
  final bool fallDetected;
  final double confidence;
  final String modelVersion;
  final int latencyMs;

  const WindowPrediction({
    required this.windowId,
    required this.fallDetected,
    required this.confidence,
    required this.modelVersion,
    required this.latencyMs,
  });

  factory WindowPrediction.fromJson(Map<String, dynamic> json) {
    final p = json['prediction'] as Map<String, dynamic>;
    return WindowPrediction(
      windowId: json['windowId'] as String,
      fallDetected: p['fallDetected'] as bool,
      confidence: (p['confidence'] as num).toDouble(),
      modelVersion: p['modelVersion'] as String,
      latencyMs: p['latencyMs'] as int,
    );
  }
}

/// Estado de monitorización en tiempo real (spec §6.3 GET /status)
class MonitoringStatusResponse {
  final String monitoringStatus; // ACTIVE | INACTIVE
  final DateTime? lastWindowAt;
  final WindowPrediction? lastPrediction;

  const MonitoringStatusResponse({
    required this.monitoringStatus,
    this.lastWindowAt,
    this.lastPrediction,
  });
}

/// Servicio de telemetría — spec §6.3
class TelemetryService {
  TelemetryService({bool? useMock})
      : _useMock = useMock ?? AppConfig.useMock;

  final bool _useMock;
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/telemetry';

  final _random = Random();

  // ── Interfaz pública ───────────────────────────────────────────────────────

  /// POST /windows — enviar ventana de sensores y recibir predicción (RF-11/12)
  ///
  /// [samples] debe contener listas de igual longitud para:
  /// accX, accY, accZ, gyroX, gyroY, gyroZ
  Future<WindowPrediction> sendWindow({
    required String monitoredPersonId,
    required String deviceId,
    required DateTime windowStart,
    required DateTime windowEnd,
    required int sampleRateHz,
    required Map<String, List<double>> samples,
    Map<String, double>? context, // heartRate, roomTemp, roomLight
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 150));

      // Simular la clasificación por umbrales igual que el backend actual
      final accX = samples['accX'] ?? [];
      final accY = samples['accY'] ?? [];
      final accZ = samples['accZ'] ?? [];
      final gyroX = samples['gyroX'] ?? [];
      final gyroY = samples['gyroY'] ?? [];
      final gyroZ = samples['gyroZ'] ?? [];

      bool fallDetected = false;
      if (accX.isNotEmpty) {
        final accelMags = List.generate(accX.length, (i) {
          final ax = accX[i], ay = accY[i], az = accZ[i];
          return sqrt(ax * ax + ay * ay + az * az);
        });
        final gyroMags = List.generate(gyroX.length, (i) {
          final gx = gyroX[i], gy = gyroY[i], gz = gyroZ[i];
          return sqrt(gx * gx + gy * gy + gz * gz);
        });
        final maxAccel = accelMags.reduce(max);
        final maxGyro = gyroMags.reduce(max);
        fallDetected = maxAccel > 15 || maxGyro > 300;
      }

      final confidence = fallDetected
          ? 0.75 + _random.nextDouble() * 0.24
          : 0.03 + _random.nextDouble() * 0.10;

      return WindowPrediction(
        windowId: 'mock-window-${DateTime.now().millisecondsSinceEpoch}',
        fallDetected: fallDetected,
        confidence: double.parse(confidence.toStringAsFixed(3)),
        modelVersion: 'xgb-1.2.0',
        latencyMs: 100 + _random.nextInt(100),
      );
    }

    final res = await http.post(
      Uri.parse('$_base/windows'),
      headers: _headers(),
      body: jsonEncode({
        'monitoredPersonId': monitoredPersonId,
        'deviceId': deviceId,
        'windowStart': windowStart.toUtc().toIso8601String(),
        'windowEnd': windowEnd.toUtc().toIso8601String(),
        'sampleRateHz': sampleRateHz,
        'samples': samples,
        // ignore: use_null_aware_elements
        if (context != null) 'context': context,
      }),
    );
    _checkStatus(res);
    return WindowPrediction.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// GET /status/{monitoredPersonId} — estado en tiempo real (rol CAREGIVER)
  Future<MonitoringStatusResponse> getStatus(String monitoredPersonId) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MonitoringStatusResponse(
        monitoringStatus: 'ACTIVE',
        lastWindowAt: DateTime.now().subtract(const Duration(seconds: 30)),
        lastPrediction: WindowPrediction(
          windowId: 'mock-window-last',
          fallDetected: false,
          confidence: 0.04,
          modelVersion: 'xgb-1.2.0',
          latencyMs: 120,
        ),
      );
    }

    final res = await http.get(
      Uri.parse('$_base/status/$monitoredPersonId'),
      headers: _headers(),
    );
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return MonitoringStatusResponse(
      monitoringStatus: json['monitoringStatus'] as String,
      lastWindowAt: json['lastWindowAt'] != null
          ? DateTime.parse(json['lastWindowAt'] as String)
          : null,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> _headers() => apiJsonHeaders();

  void _checkStatus(http.Response res) {
    if (res.statusCode == 403) {
      throw const TelemetryException(
          403, 'CONSENT_REQUIRED', 'Consentimiento no activo para esta persona.');
    }
    if (res.statusCode >= 400) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw TelemetryException(
        res.statusCode,
        body?['error'] as String? ?? 'ERROR',
        body?['message'] as String? ?? 'Error del servidor.',
      );
    }
  }
}
