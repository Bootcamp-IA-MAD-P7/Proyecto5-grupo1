/// Estado del job de reentrenamiento — alineado con backend RetrainDtos (T4.5).
enum RetrainStatus { idle, running, completed, failed }

extension RetrainStatusX on RetrainStatus {
  String get value {
    switch (this) {
      case RetrainStatus.idle:
        return 'idle';
      case RetrainStatus.running:
        return 'running';
      case RetrainStatus.completed:
        return 'completed';
      case RetrainStatus.failed:
        return 'failed';
    }
  }

  static RetrainStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'running':
        return RetrainStatus.running;
      case 'completed':
        return RetrainStatus.completed;
      case 'failed':
        return RetrainStatus.failed;
      default:
        return RetrainStatus.idle;
    }
  }

  /// Maps backend phase enum (DRIFT, TRAINING, …) to UI status.
  static RetrainStatus fromBackendPhase(String? phase) {
    if (phase == null || phase.isEmpty) return RetrainStatus.idle;
    switch (phase.toUpperCase()) {
      case 'COMPLETED':
        return RetrainStatus.completed;
      case 'FAILED':
        return RetrainStatus.failed;
      case 'IDLE':
        return RetrainStatus.idle;
      default:
        return RetrainStatus.running;
    }
  }
}

class RetrainDetails {
  final double? currentRecall;
  final double? newRecall;
  final double? overfittingGap;
  final bool? driftDetected;
  final bool? modelReloaded;

  const RetrainDetails({
    this.currentRecall,
    this.newRecall,
    this.overfittingGap,
    this.driftDetected,
    this.modelReloaded,
  });

  factory RetrainDetails.fromJson(Map<String, dynamic> json) {
    return RetrainDetails(
      currentRecall: _asDouble(json['currentRecall'] ?? json['current_recall']),
      newRecall: _asDouble(json['newRecall'] ?? json['recall']),
      overfittingGap: _asDouble(json['overfittingGap'] ?? json['overfitting']),
      driftDetected: json['driftDetected'] as bool? ?? json['drift_detected'] as bool?,
      modelReloaded: json['modelReloaded'] as bool? ?? json['model_reloaded'] as bool?,
    );
  }

  factory RetrainDetails.fromMetrics(Map<String, dynamic>? metrics, {String? decision}) {
    if (metrics == null) return const RetrainDetails();
    return RetrainDetails(
      currentRecall: _asDouble(metrics['current_recall'] ?? metrics['currentRecall']),
      newRecall: _asDouble(metrics['recall'] ?? metrics['newRecall']),
      overfittingGap: _asDouble(metrics['overfitting'] ?? metrics['overfittingGap']),
      driftDetected: metrics['drift_detected'] as bool? ?? metrics['driftDetected'] as bool?,
      modelReloaded: decision?.toLowerCase() == 'promoted',
    );
  }
}

class RetrainJobStatus {
  final RetrainStatus status;
  final String? phase;
  final String? message;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? decision;
  final String? modelVersion;
  final RetrainDetails? details;

  const RetrainJobStatus({
    required this.status,
    this.phase,
    this.message,
    this.startedAt,
    this.finishedAt,
    this.decision,
    this.modelVersion,
    this.details,
  });

  bool get isRunning => status == RetrainStatus.running;

  factory RetrainJobStatus.fromJson(Map<String, dynamic> json) {
    // Backend RetrainDtos: phase + decision + metrics (T4.4/T4.5)
    if (json.containsKey('phase')) {
      final phase = json['phase'] as String?;
      final decision = (json['decision'] as String?)?.toLowerCase();
      final metrics = json['metrics'] as Map<String, dynamic>?;
      return RetrainJobStatus(
        status: RetrainStatusX.fromBackendPhase(phase),
        phase: phase?.toLowerCase(),
        message: json['message'] as String?,
        startedAt: _parseInstant(json['startedAt']),
        finishedAt: _parseInstant(json['completedAt'] ?? json['finishedAt']),
        decision: decision == 'pending' ? null : decision,
        modelVersion: json['modelVersion'] as String?,
        details: RetrainDetails.fromMetrics(metrics, decision: decision),
      );
    }

    // Legacy mock format (tests antiguos)
    return RetrainJobStatus(
      status: RetrainStatusX.fromString(json['status'] as String? ?? 'idle'),
      phase: json['phase'] as String?,
      message: json['message'] as String?,
      startedAt: _parseInstant(json['startedAt']),
      finishedAt: _parseInstant(json['finishedAt']),
      decision: json['decision'] as String?,
      modelVersion: json['modelVersion'] as String?,
      details: json['details'] != null
          ? RetrainDetails.fromJson(json['details'] as Map<String, dynamic>)
          : null,
    );
  }
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

DateTime? _parseInstant(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
