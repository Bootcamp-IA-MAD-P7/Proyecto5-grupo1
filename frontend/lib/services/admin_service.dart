import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/alert.dart';
import '../models/monitored_person.dart';
import '../models/retrain_prerequisites.dart';
import '../models/retrain_status.dart';
import '../models/user.dart';
import 'api_headers.dart';
import 'exceptions.dart';
import 'session_manager.dart';

/// Resultado de descarga autenticada del export CSV (RF-42).
class ExportDownload {
  final List<int> bytes;
  final String filename;

  const ExportDownload({required this.bytes, required this.filename});
}

/// Entrada del historial global IT (spec §6.6)
class HistoryEntry {
  final String id;
  final String monitoredPersonId;
  final String monitoredPersonName;
  final DateTime detectedAt;
  final bool fallDetected;
  final double confidence;
  final String modelVersion;
  final AlertStatus alertStatus;
  final String? feedbackLabel; // TRUE_FALL | FALSE_ALARM | null

  const HistoryEntry({
    required this.id,
    required this.monitoredPersonId,
    required this.monitoredPersonName,
    required this.detectedAt,
    required this.fallDetected,
    required this.confidence,
    required this.modelVersion,
    required this.alertStatus,
    this.feedbackLabel,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      // Backend (spec §6.6) envía 'alertId'.
      id: (json['alertId'] ?? json['id']) as String,
      monitoredPersonId: json['monitoredPersonId'] as String,
      monitoredPersonName: json['monitoredPersonName'] as String,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      // El backend no envía 'fallDetected': una entrada del historial es una
      // alerta y las alertas solo se crean cuando hubo caída detectada.
      fallDetected: json['fallDetected'] as bool? ?? true,
      confidence: (json['confidence'] as num).toDouble(),
      modelVersion: json['modelVersion'] as String,
      alertStatus: AlertStatusX.fromString(json['alertStatus'] as String),
      feedbackLabel: json['feedbackLabel'] as String?,
    );
  }
}

/// Servicio de administración IT — spec §6.6 (backend Java real).
///
/// [client] es inyectable para tests (`MockClient` de `package:http/testing`).
class AdminService {
  AdminService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/admin';

  /// GET /history — historial global paginado (RF-18)
  Future<PagedResponse<HistoryEntry>> getHistory({
    int page = 0,
    int size = 20,
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      'sort': 'detectedAt,desc',
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('$_base/history').replace(queryParameters: params);
    final res = await _client.get(uri, headers: _headers());
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (json['content'] as List)
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResponse(
      content: content,
      page: (json['page'] ?? json['number'] ?? 0) as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  /// GET /export — dataset etiquetado para reentrenamiento (RF-19, RF-42).
  /// Descarga el CSV autenticado con Bearer (sin URL pública).
  Future<ExportDownload> downloadExport({DateTime? from, DateTime? to}) async {
    final params = <String, String>{
      'format': 'csv',
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('$_base/export').replace(queryParameters: params);
    final res = await _client.get(uri, headers: _authHeaders());
    _checkStatus(res);
    return ExportDownload(
      bytes: res.bodyBytes,
      filename: _parseExportFilename(res.headers['content-disposition']),
    );
  }

  /// GET /users — listado de usuarios (RF-04)
  Future<PagedResponse<User>> getUsers({int page = 0, int size = 20}) async {
    final res = await _client.get(
      Uri.parse('$_base/users?page=$page&size=$size'),
      headers: _headers(),
    );
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (json['content'] as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResponse(
      content: content,
      page: (json['page'] ?? json['number'] ?? 0) as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  /// PATCH /users/{id} — activar/desactivar usuario (RF-04)
  Future<User> setUserActive(String userId, {required bool active}) async {
    final res = await _client.patch(
      Uri.parse('$_base/users/$userId'),
      headers: _headers(),
      body: jsonEncode({'active': active}),
    );
    _checkStatus(res);
    return User.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// GET /retrain/prerequisites — elegibilidad feedback (RF-45)
  Future<RetrainPrerequisites> getRetrainPrerequisites() async {
    final res = await _client.get(
      Uri.parse('$_base/retrain/prerequisites'),
      headers: _headers(),
    );
    _checkStatus(res);
    return RetrainPrerequisites.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST /retrain — lanzar reentrenamiento (RF-33)
  Future<void> startRetrain() async {
    final res = await _client.post(
      Uri.parse('$_base/retrain'),
      headers: _headers(),
    );
    _checkStatus(res);
  }

  /// GET /retrain/status — estado del job de reentrenamiento (RF-33)
  Future<RetrainJobStatus> getRetrainStatus() async {
    final res = await _client.get(
      Uri.parse('$_base/retrain/status'),
      headers: _headers(),
    );
    _checkStatus(res);
    return RetrainJobStatus.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> _headers() => apiJsonHeaders();

  Map<String, String> _authHeaders() {
    final headers = <String, String>{};
    final token = SessionManager().accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _parseExportFilename(String? contentDisposition) {
    if (contentDisposition == null) {
      return 'sentilife-feedback.csv';
    }
    final match = RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
    return match?.group(1) ?? 'sentilife-feedback.csv';
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw AdminException(
        res.statusCode,
        body?['error'] as String? ?? 'ERROR',
        body?['message'] as String? ?? 'Error del servidor.',
      );
    }
  }
}
