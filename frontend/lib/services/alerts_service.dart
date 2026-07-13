import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/alert.dart';
import '../models/monitored_person.dart';
import 'api_headers.dart';
import 'exceptions.dart';

/// Servicio de alertas — spec §6.5
class AlertsService {
  AlertsService({bool? useMock}) : _useMock = useMock ?? AppConfig.useMock;

  final bool _useMock;
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/alerts';

  // ── Mock data ──────────────────────────────────────────────────────────────

  final List<Alert> _mockAlerts = [
    Alert(
      id: 'uuid-alert-001',
      monitoredPersonId: 'uuid-person-001',
      monitoredPersonName: 'Manuel Pérez',
      detectedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      confidence: 0.92,
      modelVersion: 'xgb-1.2.0',
      status: AlertStatus.pending,
    ),
    Alert(
      id: 'uuid-alert-002',
      monitoredPersonId: 'uuid-person-001',
      monitoredPersonName: 'Manuel Pérez',
      detectedAt: DateTime.now().subtract(const Duration(hours: 3)),
      confidence: 0.87,
      modelVersion: 'xgb-1.2.0',
      status: AlertStatus.confirmed,
    ),
    Alert(
      id: 'uuid-alert-003',
      monitoredPersonId: 'uuid-person-001',
      monitoredPersonName: 'Manuel Pérez',
      detectedAt: DateTime.now().subtract(const Duration(days: 1)),
      confidence: 0.61,
      modelVersion: 'xgb-1.2.0',
      status: AlertStatus.dismissed,
    ),
  ];

  // ── Interfaz pública ───────────────────────────────────────────────────────

  /// GET / — listado de alertas del cuidador, filtros opcionales
  Future<PagedResponse<Alert>> list({
    AlertStatus? status,
    String? monitoredPersonId,
    int page = 0,
    int size = 20,
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      var filtered = List<Alert>.from(_mockAlerts);
      if (status != null) {
        filtered = filtered.where((a) => a.status == status).toList();
      }
      if (monitoredPersonId != null) {
        filtered = filtered
            .where((a) => a.monitoredPersonId == monitoredPersonId)
            .toList();
      }
      return PagedResponse(
        content: filtered,
        page: page,
        size: size,
        totalElements: filtered.length,
        totalPages: 1,
      );
    }

    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      // ignore: use_null_aware_elements
      if (status != null) 'status': status.value,
      // ignore: use_null_aware_elements
      if (monitoredPersonId != null) 'monitoredPersonId': monitoredPersonId,
    };
    final uri = Uri.parse(_base).replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers());
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (json['content'] as List)
        .map((e) => Alert.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResponse(
      content: content,
      page: json['page'] as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  /// Obtiene una alerta por ID (p. ej. navegación desde push FCM).
  Future<Alert?> getById(String id) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 150));
      for (final alert in _mockAlerts) {
        if (alert.id == id) return alert;
      }
      return null;
    }

    final page = await list(size: 100);
    for (final alert in page.content) {
      if (alert.id == id) return alert;
    }
    return null;
  }

  /// PATCH /{id} — confirmar o descartar alerta (RF-17)
  Future<Alert> review(
    String id, {
    required AlertStatus status,
    String? comment,
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockAlerts.indexWhere((a) => a.id == id);
      if (idx == -1) {
        throw ApiException(404, 'NOT_FOUND', 'Alerta no encontrada.');
      }
      final updated = _mockAlerts[idx].copyWith(status: status);
      _mockAlerts[idx] = updated;
      return updated;
    }

    final res = await http.patch(
      Uri.parse('$_base/$id'),
      headers: _headers(),
      body: jsonEncode({
        'status': status.value,
        // ignore: use_null_aware_elements
        if (comment != null) 'comment': comment,
      }),
    );
    _checkStatus(res);
    return Alert.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
