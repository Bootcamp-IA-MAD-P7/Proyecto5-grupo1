/// Estado local del perfil MONITORED: persona vinculada + consentimiento.
///
/// T2.21 (pairing) escribe [monitoredPersonId] y [deviceId].
/// T2.20 marca [consentActive] tras `POST /{id}/consent` exitoso.
class MonitoredContextStore {
  static final MonitoredContextStore _instance = MonitoredContextStore._();
  factory MonitoredContextStore() => _instance;
  MonitoredContextStore._();

  String? monitoredPersonId;
  String? deviceId;
  bool consentActive = false;

  bool get isPaired =>
      monitoredPersonId != null &&
      monitoredPersonId!.isNotEmpty &&
      deviceId != null &&
      deviceId!.isNotEmpty;

  void setPairing({
    required String personId,
    required String deviceId,
  }) {
    monitoredPersonId = personId;
    this.deviceId = deviceId;
    consentActive = false;
  }

  void setConsentActive(bool active) {
    consentActive = active;
  }

  void clear() {
    monitoredPersonId = null;
    deviceId = null;
    consentActive = false;
  }
}

/// Versión de política GDPR según idioma activo (spec §6.2 / ADR-08).
String consentPolicyVersion(String languageCode) => '1.0-$languageCode';
