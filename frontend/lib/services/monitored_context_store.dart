import 'package:shared_preferences/shared_preferences.dart';

/// Estado local del perfil MONITORED: persona vinculada + consentimiento.
///
/// T2.21 (pairing) escribe [monitoredPersonId] y [deviceId].
/// T2.20 marca [consentActive] tras `POST /{id}/consent` exitoso.
/// T2.29 persiste el pairing en disco para que sobreviva al reinicio de la app.
class MonitoredContextStore {
  static final MonitoredContextStore _instance = MonitoredContextStore._();
  factory MonitoredContextStore() => _instance;
  MonitoredContextStore._();

  static const _kPersonId = 'monitored_person_id';
  static const _kDeviceId = 'monitored_device_id';
  static const _kConsent = 'monitored_consent_active';

  String? monitoredPersonId;
  String? deviceId;
  bool consentActive = false;
  bool _loaded = false;

  bool get isPaired =>
      monitoredPersonId != null &&
      monitoredPersonId!.isNotEmpty &&
      deviceId != null &&
      deviceId!.isNotEmpty;

  /// Rehidrata el estado persistido. Idempotente: solo lee la primera vez.
  /// Debe llamarse al abrir la pantalla MONITORED. Los fallos de almacenamiento
  /// (p. ej. Web sin storage) se ignoran y se conserva el estado en memoria.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      monitoredPersonId = prefs.getString(_kPersonId);
      deviceId = prefs.getString(_kDeviceId);
      consentActive = prefs.getBool(_kConsent) ?? false;
    } catch (_) {
      // almacenamiento no disponible: se mantiene el estado en memoria
    }
    _loaded = true;
  }

  void setPairing({
    required String personId,
    required String deviceId,
  }) {
    monitoredPersonId = personId;
    this.deviceId = deviceId;
    consentActive = false;
    _loaded = true;
    _persist();
  }

  void setConsentActive(bool active) {
    consentActive = active;
    _persist();
  }

  void clear() {
    monitoredPersonId = null;
    deviceId = null;
    consentActive = false;
    _loaded = true;
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (monitoredPersonId == null) {
        await prefs.remove(_kPersonId);
      } else {
        await prefs.setString(_kPersonId, monitoredPersonId!);
      }
      if (deviceId == null) {
        await prefs.remove(_kDeviceId);
      } else {
        await prefs.setString(_kDeviceId, deviceId!);
      }
      await prefs.setBool(_kConsent, consentActive);
    } catch (_) {
      // se ignoran fallos de persistencia (p. ej. Web sin storage)
    }
  }
}

/// Versión de política GDPR según idioma activo (spec §6.2 / ADR-08).
String consentPolicyVersion(String languageCode) => '1.0-$languageCode';
