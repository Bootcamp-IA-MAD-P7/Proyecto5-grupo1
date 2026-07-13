/// Payload `data` de push FCM — spec §6.4 (RF-28/RF-29).
class PushAlertPayload {
  final String type;
  final String alertId;
  final String? monitoredPersonId;
  final String? personName;
  final double? confidence;

  const PushAlertPayload({
    required this.type,
    required this.alertId,
    this.monitoredPersonId,
    this.personName,
    this.confidence,
  });

  bool get isFallAlert => type == 'FALL_ALERT';

  factory PushAlertPayload.fromData(Map<String, dynamic> data) {
    return PushAlertPayload(
      type: data['type'] as String? ?? '',
      alertId: data['alertId'] as String? ?? '',
      monitoredPersonId: data['monitoredPersonId'] as String?,
      personName: data['personName'] as String?,
      confidence: _parseConfidence(data['confidence']),
    );
  }

  static double? _parseConfidence(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
