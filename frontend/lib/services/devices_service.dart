import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_headers.dart';
import 'exceptions.dart';

/// Resultado del emparejamiento de dispositivo (spec §6.4)
class PairResult {
  final String monitoredPersonId;
  final String deviceToken;

  const PairResult({
    required this.monitoredPersonId,
    required this.deviceToken,
  });

  factory PairResult.fromJson(Map<String, dynamic> json) {
    return PairResult(
      monitoredPersonId: json['monitoredPersonId'] as String,
      deviceToken: json['deviceToken'] as String,
    );
  }
}

/// Servicio de gestión de dispositivos — spec §6.4 (backend Java real).
///
/// [client] es inyectable para tests (`MockClient` de `package:http/testing`).
class DevicesService {
  DevicesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/devices';

  /// POST /pair — vincula dispositivo del monitoreado con su pairingCode
  Future<PairResult> pair({
    required String pairingCode,
    required String deviceId,
    String platform = 'ANDROID',
  }) async {
    final res = await _client.post(
      Uri.parse('$_base/pair'),
      headers: apiJsonHeaders(requireAuth: false),
      body: jsonEncode({
        'pairingCode': pairingCode,
        'deviceId': deviceId,
        'platform': platform,
      }),
    );
    _checkStatus(res);
    return PairResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST /push-token — registra token FCM del cuidador (RF-27), idempotente
  Future<void> registerPushToken({
    required String fcmToken,
    required String deviceId,
    String platform = 'ANDROID',
    String locale = 'es',
  }) async {
    final res = await _client.post(
      Uri.parse('$_base/push-token'),
      headers: _headers(),
      body: jsonEncode({
        'fcmToken': fcmToken,
        'deviceId': deviceId,
        'platform': platform,
        'locale': locale,
      }),
    );
    _checkStatus(res);
  }

  Map<String, String> _headers() => apiJsonHeaders();

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw DeviceException(
        res.statusCode,
        body?['error'] as String? ?? 'ERROR',
        body?['message'] as String? ?? 'Error del servidor.',
      );
    }
  }
}
