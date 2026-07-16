import 'dart:convert';
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

/// Servicio de telemetría — spec §6.3 (backend Java real).
///
/// [client] es inyectable para tests (`MockClient` de `package:http/testing`).
class TelemetryService {
  TelemetryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/telemetry';

  /// POST /windows — enviar ventana de sensores y recibir predicción (RF-11/12)
  ///
  /// [samples] debe contener listas de igual longitud para:
  /// accX, accY, accZ, gyroX, gyroY, gyroZ
  Future<WindowPrediction> sendWindow({
    required String monitoredPersonId,
    required String deviceId,
    required String deviceToken,
    required DateTime windowStart,
    required DateTime windowEnd,
    required int sampleRateHz,
    required Map<String, List<double>> samples,
    Map<String, double>? context, // heartRate, roomTemp, roomLight
  }) async {
    final res = await _client.post(
      Uri.parse('$_base/windows'),
      headers: _deviceHeaders(deviceToken),
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
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// GET /status/{monitoredPersonId} — estado en tiempo real (rol CAREGIVER)
  Future<MonitoringStatusResponse> getStatus(String monitoredPersonId) async {
    final res = await _client.get(
      Uri.parse('$_base/status/$monitoredPersonId'),
      headers: await _headers(),
    );
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final lp = json['lastPrediction'] as Map<String, dynamic>?;
    return MonitoringStatusResponse(
      monitoringStatus: json['monitoringStatus'] as String,
      lastWindowAt: json['lastWindowAt'] != null
          ? DateTime.parse(json['lastWindowAt'] as String)
          : null,
      // Backend (spec §6.3) envía lastPrediction plano (sin windowId ni objeto
      // 'prediction' anidado), así que se construye el WindowPrediction a mano.
      lastPrediction: lp != null
          ? WindowPrediction(
              windowId: (lp['windowId'] ?? '') as String,
              fallDetected: lp['fallDetected'] as bool,
              confidence: (lp['confidence'] as num).toDouble(),
              modelVersion: lp['modelVersion'] as String,
              latencyMs: (lp['latencyMs'] as num?)?.toInt() ?? 0,
            )
          : null,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers() => apiJsonHeadersAsync();

  Map<String, String> _deviceHeaders(String deviceToken) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $deviceToken',
  };

  void _checkStatus(http.Response res) {
    if (res.statusCode == 403) {
      throw const TelemetryException(
        403,
        'CONSENT_REQUIRED',
        'Consentimiento no activo para esta persona.',
      );
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
