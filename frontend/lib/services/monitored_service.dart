import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/monitored_person.dart';
import 'api_headers.dart';
import 'exceptions.dart';

/// Servicio de personas monitorizadas — spec §6.2
class MonitoredService {
  MonitoredService({bool? useMock})
      : _useMock = useMock ?? AppConfig.useMock;

  final bool _useMock;
  static const String _base =
      '${AppConfig.apiBaseUrl}/api/v1/monitored-persons';

  // ── Mock data ──────────────────────────────────────────────────────────────

  final List<MonitoredPerson> _mockPersons = [
    MonitoredPerson(
      id: 'uuid-person-001',
      fullName: 'Manuel Pérez',
      birthDate: '1948-03-12',
      age: 78,
      sex: 'M',
      weightKg: 78.5,
      heightCm: 172,
      emergencyContact: '+34600111222',
      consentStatus: ConsentStatus.active,
      monitoringStatus: MonitoringStatus.active,
      pairingCode: 'SL-84F2K9',
      createdAt: DateTime.parse('2026-07-08T10:00:00Z'),
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 2)),
      lastPrediction: LastPrediction(
        fallDetected: false,
        confidence: 0.03,
        modelVersion: 'xgb-1.2.0',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ),
    MonitoredPerson(
      id: 'uuid-person-002',
      fullName: 'Carmen López',
      birthDate: '1952-07-24',
      age: 73,
      sex: 'F',
      weightKg: 61.0,
      heightCm: 158,
      emergencyContact: '+34611222333',
      consentStatus: ConsentStatus.pending,
      monitoringStatus: MonitoringStatus.inactive,
      pairingCode: 'SL-77X3M1',
      createdAt: DateTime.parse('2026-07-07T09:00:00Z'),
    ),
  ];

  // ── Interfaz pública ───────────────────────────────────────────────────────

  /// GET / — lista paginada de personas del cuidador
  Future<PagedResponse<MonitoredPerson>> list({
    int page = 0,
    int size = 20,
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return PagedResponse(
        content: _mockPersons,
        page: page,
        size: size,
        totalElements: _mockPersons.length,
        totalPages: 1,
      );
    }

    final res = await http.get(
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
      page: json['page'] as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  /// GET /{id}
  Future<MonitoredPerson> get(String id) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _mockPersons.firstWhere(
        (p) => p.id == id,
        orElse: () => throw ApiException(404, 'NOT_FOUND', 'Persona no encontrada.'),
      );
    }

    final res = await http.get(Uri.parse('$_base/$id'), headers: _headers());
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
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      final now = DateTime.now();
      final age = now.year - int.parse(birthDate.split('-')[0]);
      final person = MonitoredPerson(
        id: 'uuid-person-${now.millisecondsSinceEpoch}',
        fullName: fullName,
        birthDate: birthDate,
        age: age,
        sex: sex,
        weightKg: weightKg,
        heightCm: heightCm,
        emergencyContact: emergencyContact,
        consentStatus: ConsentStatus.pending,
        monitoringStatus: MonitoringStatus.inactive,
        pairingCode: 'SL-${(now.millisecondsSinceEpoch % 999999).toString().padLeft(6, '0')}',
        createdAt: now,
      );
      _mockPersons.add(person);
      return person;
    }

    final res = await http.post(
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
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      _mockPersons.removeWhere((p) => p.id == id);
      return;
    }

    final res =
        await http.delete(Uri.parse('$_base/$id'), headers: _headers());
    _checkStatus(res);
  }

  /// POST /{id}/consent — aceptar consentimiento (RF-06)
  Future<void> acceptConsent(String id, {String policyVersion = '1.0-es'}) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockPersons.indexWhere((p) => p.id == id);
      if (idx == -1) throw ApiException(404, 'NOT_FOUND', 'Persona no encontrada.');
      // El mock no puede reasignar campos final, en la app real se refresca la lista
      return;
    }

    final res = await http.post(
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
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }

    final res = await http.delete(
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
