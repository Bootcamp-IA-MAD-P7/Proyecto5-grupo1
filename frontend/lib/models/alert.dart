/// Estado de una alerta (spec §6.5)
enum AlertStatus { pending, confirmed, dismissed }

extension AlertStatusX on AlertStatus {
  String get value {
    switch (this) {
      case AlertStatus.pending:
        return 'PENDING';
      case AlertStatus.confirmed:
        return 'CONFIRMED';
      case AlertStatus.dismissed:
        return 'DISMISSED';
    }
  }

  static AlertStatus fromString(String s) {
    switch (s.toUpperCase()) {
      case 'CONFIRMED':
        return AlertStatus.confirmed;
      case 'DISMISSED':
        return AlertStatus.dismissed;
      default:
        return AlertStatus.pending;
    }
  }
}

class Alert {
  final String id;
  final String monitoredPersonId;
  final String monitoredPersonName;
  final DateTime detectedAt;
  final double confidence;
  final String modelVersion;
  final AlertStatus status;

  const Alert({
    required this.id,
    required this.monitoredPersonId,
    required this.monitoredPersonName,
    required this.detectedAt,
    required this.confidence,
    required this.modelVersion,
    required this.status,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      monitoredPersonId: json['monitoredPersonId'] as String,
      monitoredPersonName: json['monitoredPersonName'] as String,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      modelVersion: json['modelVersion'] as String,
      status: AlertStatusX.fromString(json['status'] as String),
    );
  }

  Alert copyWith({AlertStatus? status}) {
    return Alert(
      id: id,
      monitoredPersonId: monitoredPersonId,
      monitoredPersonName: monitoredPersonName,
      detectedAt: detectedAt,
      confidence: confidence,
      modelVersion: modelVersion,
      status: status ?? this.status,
    );
  }
}
