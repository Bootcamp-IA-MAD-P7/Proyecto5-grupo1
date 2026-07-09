import 'dart:convert';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/alert.dart';
import '../models/monitored_person.dart';
import '../models/retrain_status.dart';
import '../models/user.dart';
import 'exceptions.dart';

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
      id: json['id'] as String,
      monitoredPersonId: json['monitoredPersonId'] as String,
      monitoredPersonName: json['monitoredPersonName'] as String,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      fallDetected: json['fallDetected'] as bool,
      confidence: (json['confidence'] as num).toDouble(),
      modelVersion: json['modelVersion'] as String,
      alertStatus: AlertStatusX.fromString(json['alertStatus'] as String),
      feedbackLabel: json['feedbackLabel'] as String?,
    );
  }
}

/// Servicio de administración IT — spec §6.6
class AdminService {
  static const bool _useMock = true;
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/admin';

  // ── Mock data ──────────────────────────────────────────────────────────────

  final List<HistoryEntry> _mockHistory = [
    HistoryEntry(
      id: 'uuid-hist-001',
      monitoredPersonId: 'uuid-person-001',
      monitoredPersonName: 'Manuel Pérez',
      detectedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      fallDetected: true,
      confidence: 0.92,
      modelVersion: 'xgb-1.2.0',
      alertStatus: AlertStatus.pending,
    ),
    HistoryEntry(
      id: 'uuid-hist-002',
      monitoredPersonId: 'uuid-person-001',
      monitoredPersonName: 'Manuel Pérez',
      detectedAt: DateTime.now().subtract(const Duration(hours: 3)),
      fallDetected: true,
      confidence: 0.87,
      modelVersion: 'xgb-1.2.0',
      alertStatus: AlertStatus.confirmed,
      feedbackLabel: 'TRUE_FALL',
    ),
    HistoryEntry(
      id: 'uuid-hist-003',
      monitoredPersonId: 'uuid-person-001',
      monitoredPersonName: 'Manuel Pérez',
      detectedAt: DateTime.now().subtract(const Duration(days: 1)),
      fallDetected: true,
      confidence: 0.61,
      modelVersion: 'xgb-1.2.0',
      alertStatus: AlertStatus.dismissed,
      feedbackLabel: 'FALSE_ALARM',
    ),
  ];

  RetrainJobStatus _mockRetrainStatus = const RetrainJobStatus(
    status: RetrainStatus.idle,
  );

  final List<User> _mockUsers = [
    User(
        id: 'uuid-caregiver-001',
        email: 'caregiver@test.com',
        fullName: 'Ana García',
        role: UserRole.caregiver),
    User(
        id: 'uuid-monitored-001',
        email: 'monitored@test.com',
        fullName: 'Manuel Pérez',
        role: UserRole.monitored),
    User(
        id: 'uuid-admin-001',
        email: 'admin@test.com',
        fullName: 'IT Admin',
        role: UserRole.itAdmin),
  ];

  // ── Interfaz pública ───────────────────────────────────────────────────────

  /// GET /history — historial global paginado (RF-18)
  Future<PagedResponse<HistoryEntry>> getHistory({
    int page = 0,
    int size = 20,
    DateTime? from,
    DateTime? to,
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return PagedResponse(
        content: _mockHistory,
        page: page,
        size: size,
        totalElements: _mockHistory.length,
        totalPages: 1,
      );
    }

    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('$_base/history').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers());
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final content = (json['content'] as List)
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResponse(
      content: content,
      page: json['page'] as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  /// GET /export — dataset etiquetado para reentrenamiento (RF-19)
  /// Devuelve la URL de descarga del CSV.
  Future<String> getExportUrl({DateTime? from, DateTime? to}) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return 'mock://export/labeled_dataset.csv';
    }

    final params = <String, String>{
      'format': 'csv',
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('$_base/export').replace(queryParameters: params);
    return uri.toString();
  }

  /// GET /users — listado de usuarios (RF-04)
  Future<PagedResponse<User>> getUsers({int page = 0, int size = 20}) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return PagedResponse(
        content: _mockUsers,
        page: page,
        size: size,
        totalElements: _mockUsers.length,
        totalPages: 1,
      );
    }

    final res = await http.get(
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
      page: json['page'] as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  /// POST /retrain — lanzar reentrenamiento (RF-33)
  Future<void> startRetrain() async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_mockRetrainStatus.status == RetrainStatus.running) {
        throw const AdminException(
            409, 'RETRAIN_RUNNING', 'Ya hay un reentrenamiento en curso.');
      }
      _mockRetrainStatus = RetrainJobStatus(
        status: RetrainStatus.running,
        phase: 'drift',
        message: 'Analizando distribución de features...',
        startedAt: DateTime.now(),
      );
      // Simular progreso en background
      Future.delayed(const Duration(seconds: 3), () {
        _mockRetrainStatus = RetrainJobStatus(
          status: RetrainStatus.running,
          phase: 'training',
          message: 'Entrenando con datos reales etiquetados...',
          startedAt: _mockRetrainStatus.startedAt,
        );
      });
      Future.delayed(const Duration(seconds: 8), () {
        _mockRetrainStatus = RetrainJobStatus(
          status: RetrainStatus.completed,
          phase: null,
          message:
              'Modelo promovido a producción (recall 0.91 → 0.94). La API ya sirve el nuevo modelo.',
          startedAt: _mockRetrainStatus.startedAt,
          finishedAt: DateTime.now(),
          decision: 'promoted',
          details: const RetrainDetails(
            currentRecall: 0.91,
            newRecall: 0.94,
            overfittingGap: 0.03,
            driftDetected: false,
            modelReloaded: true,
          ),
        );
      });
      return;
    }

    final res = await http.post(
      Uri.parse('$_base/retrain'),
      headers: _headers(),
    );
    _checkStatus(res);
  }

  /// GET /retrain/status — estado del job de reentrenamiento (RF-33)
  Future<RetrainJobStatus> getRetrainStatus() async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _mockRetrainStatus;
    }

    final res = await http.get(
      Uri.parse('$_base/retrain/status'),
      headers: _headers(),
    );
    _checkStatus(res);
    return RetrainJobStatus.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer mock-access-token',
      };

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
