import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/alert.dart';
import '../models/monitored_person.dart';
import 'api_headers.dart';
import 'exceptions.dart';

/// Servicio de alertas — spec §6.5 (backend Java real).
///
/// [client] es inyectable para tests (`MockClient` de `package:http/testing`).
class AlertsService {
  AlertsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/alerts';

  /// GET / — listado de alertas del cuidador, filtros opcionales
  Future<PagedResponse<Alert>> list({
    AlertStatus? status,
    String? monitoredPersonId,
    int page = 0,
    int size = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      // ignore: use_null_aware_elements
      if (status != null) 'status': status.value,
      // ignore: use_null_aware_elements
      if (monitoredPersonId != null) 'monitoredPersonId': monitoredPersonId,
    };
    final uri = Uri.parse(_base).replace(queryParameters: params);
    final res = await _client.get(uri, headers: _headers());
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (json['content'] as List)
        .map((e) => Alert.fromJson(e as Map<String, dynamic>))
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

  /// Obtiene una alerta por ID (p. ej. navegación desde push FCM).
  Future<Alert?> getById(String id) async {
    final page = await list(size: 100);
    for (final alert in page.content) {
      if (alert.id == id) return alert;
    }
    return null;
  }

  /// PATCH /{id} — confirmar o descartar alerta (RF-17).
  ///
  /// El backend responde `{ alertId, status, feedbackLabelId }` (spec §6.5),
  /// no la alerta completa, por eso no se hace `Alert.fromJson` de la respuesta.
  Future<void> review(
    String id, {
    required AlertStatus status,
    String? comment,
  }) async {
    final res = await _client.patch(
      Uri.parse('$_base/$id'),
      headers: _headers(),
      body: jsonEncode({
        'status': status.value,
        // ignore: use_null_aware_elements
        if (comment != null) 'comment': comment,
      }),
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
