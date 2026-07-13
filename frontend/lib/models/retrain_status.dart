/// Estado del job de reentrenamiento (spec §6.6)
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
}

class RetrainDetails {
  final double currentRecall;
  final double newRecall;
  final double overfittingGap;
  final bool driftDetected;
  final bool modelReloaded;

  const RetrainDetails({
    required this.currentRecall,
    required this.newRecall,
    required this.overfittingGap,
    required this.driftDetected,
    required this.modelReloaded,
  });

  factory RetrainDetails.fromJson(Map<String, dynamic> json) {
    return RetrainDetails(
      currentRecall: (json['currentRecall'] as num).toDouble(),
      newRecall: (json['newRecall'] as num).toDouble(),
      overfittingGap: (json['overfittingGap'] as num).toDouble(),
      driftDetected: json['driftDetected'] as bool,
      modelReloaded: json['modelReloaded'] as bool,
    );
  }
}

class RetrainJobStatus {
  final RetrainStatus status;
  final String? phase; // drift | training | reload
  final String? message;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? decision; // promoted | candidate | discarded | skipped
  final RetrainDetails? details;

  const RetrainJobStatus({
    required this.status,
    this.phase,
    this.message,
    this.startedAt,
    this.finishedAt,
    this.decision,
    this.details,
  });

  factory RetrainJobStatus.fromJson(Map<String, dynamic> json) {
    return RetrainJobStatus(
      status: RetrainStatusX.fromString(json['status'] as String),
      phase: json['phase'] as String?,
      message: json['message'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
      decision: json['decision'] as String?,
      details: json['details'] != null
          ? RetrainDetails.fromJson(json['details'] as Map<String, dynamic>)
          : null,
    );
  }
}
