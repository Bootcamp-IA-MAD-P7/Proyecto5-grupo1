/// Estado de consentimiento GDPR (spec §6.2)
enum ConsentStatus { pending, active, revoked }

extension ConsentStatusX on ConsentStatus {
  String get value {
    switch (this) {
      case ConsentStatus.pending:
        return 'PENDING';
      case ConsentStatus.active:
        return 'ACTIVE';
      case ConsentStatus.revoked:
        return 'REVOKED';
    }
  }

  static ConsentStatus fromString(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE':
        return ConsentStatus.active;
      case 'REVOKED':
        return ConsentStatus.revoked;
      default:
        return ConsentStatus.pending;
    }
  }
}

/// Estado de monitorización
enum MonitoringStatus { active, inactive }

extension MonitoringStatusX on MonitoringStatus {
  String get value =>
      this == MonitoringStatus.active ? 'ACTIVE' : 'INACTIVE';

  static MonitoringStatus fromString(String s) =>
      s.toUpperCase() == 'ACTIVE'
          ? MonitoringStatus.active
          : MonitoringStatus.inactive;
}

/// Datos de la última predicción embebida en la persona (spec §6.3)
class LastPrediction {
  final bool fallDetected;
  final double confidence;
  final String modelVersion;
  final DateTime timestamp;

  const LastPrediction({
    required this.fallDetected,
    required this.confidence,
    required this.modelVersion,
    required this.timestamp,
  });

  factory LastPrediction.fromJson(Map<String, dynamic> json) {
    return LastPrediction(
      fallDetected: json['fallDetected'] as bool,
      confidence: (json['confidence'] as num).toDouble(),
      modelVersion: json['modelVersion'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Persona monitorizada registrada por un cuidador (spec §6.2)
class MonitoredPerson {
  final String id;
  final String fullName;
  final String birthDate; // ISO-8601 date
  final int age;
  final String sex; // M | F | OTHER
  final double weightKg;
  final double heightCm;
  final String? emergencyContact;
  final ConsentStatus consentStatus;
  final MonitoringStatus monitoringStatus;
  final String? pairingCode;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final LastPrediction? lastPrediction;

  const MonitoredPerson({
    required this.id,
    required this.fullName,
    required this.birthDate,
    required this.age,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    this.emergencyContact,
    required this.consentStatus,
    required this.monitoringStatus,
    this.pairingCode,
    required this.createdAt,
    this.lastSeenAt,
    this.lastPrediction,
  });

  factory MonitoredPerson.fromJson(Map<String, dynamic> json) {
    return MonitoredPerson(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      birthDate: json['birthDate'] as String,
      age: json['age'] as int,
      sex: json['sex'] as String,
      weightKg: (json['weightKg'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      emergencyContact: json['emergencyContact'] as String?,
      consentStatus:
          ConsentStatusX.fromString(json['consentStatus'] as String),
      monitoringStatus:
          MonitoringStatusX.fromString(json['monitoringStatus'] as String),
      pairingCode: json['pairingCode'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'] as String)
          : null,
      lastPrediction: json['lastPrediction'] != null
          ? LastPrediction.fromJson(
              json['lastPrediction'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Respuesta paginada genérica (spec §6 convenciones)
class PagedResponse<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const PagedResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });
}
