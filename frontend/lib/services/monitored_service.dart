import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/monitored_person.dart';
import 'api_headers.dart';
import 'exceptions.dart';

/// Servicio de personas monitorizadas — spec §6.2 (backend Java real).
///
/// [client] es inyectable para tests (`MockClient` de `package:http/testing`).
class MonitoredService {
  MonitoredService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base =
      '${AppConfig.apiBaseUrl}/api/v1/monitored-persons';

  /// GET / — lista paginada de personas del cuidador
  Future<PagedResponse<MonitoredPerson>> list({
    int page = 0,
    int size = 20,
  }) async {
    final res = await _client.get(
      Uri.parse('$_base?page=$page&size=$size'),
      headers: _headers(),
    );
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (json['content'] as List)
        .map((e) => MonitoredPerson.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResponse(
      content: content,
      // Spring serializa Page con 'number'; la spec usa 'page'.
      page: (json['page'] ?? json['number'] ?? 0) as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  /// GET /{id}
  Future<MonitoredPerson> get(String id) async {
    final res = await _client.get(Uri.parse('$_base/$id'), headers: _headers());
    _checkStatus(res);
    return MonitoredPerson.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST / — registrar nueva persona
  Future<MonitoredPerson> create({
    required String fullName,
    required String birthDate,
    required String sex,
    required double weightKg,
    required double heightCm,
    String? emergencyContact,
  }) async {
    final res = await _client.post(
      Uri.parse(_base),
      headers: _headers(),
      body: jsonEncode({
        'fullName': fullName,
        'birthDate': birthDate,
        'sex': sex,
        'weightKg': weightKg,
        'heightCm': heightCm,
        // ignore: use_null_aware_elements
        if (emergencyContact != null) 'emergencyContact': emergencyContact,
      }),
    );
    _checkStatus(res);
    return MonitoredPerson.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// DELETE /{id} — supresión GDPR (RF-08)
  Future<void> delete(String id) async {
    final res =
        await _client.delete(Uri.parse('$_base/$id'), headers: _headers());
    _checkStatus(res);
  }

  /// POST /{id}/consent — aceptar consentimiento (RF-06)
  Future<void> acceptConsent(String id, {String policyVersion = '1.0-es'}) async {
    final res = await _client.post(
      Uri.parse('$_base/$id/consent'),
      headers: _headers(),
      body: jsonEncode({
        'policyVersion': policyVersion,
        'acceptedBy': 'MONITORED',
      }),
    );
    _checkStatus(res);
  }

  /// DELETE /{id}/consent — revocar consentimiento (RF-07)
  Future<void> revokeConsent(String id) async {
    final res = await _client.delete(
      Uri.parse('$_base/$id/consent'),
      headers: _headers(),
    );
    _checkStatus(res);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> _headers() => apiJsonHeaders();

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw ApiException(
        res.statusCode,
        body?['error'] as String? ?? 'ERROR',
        body?['message'] as String? ?? 'Error del servidor.',
      );
    }
  }
}
