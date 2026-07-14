import 'package:flutter/foundation.dart';
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
  static const _kDeviceToken = 'monitored_device_token';
  static const _kConsent = 'monitored_consent_active';

  String? monitoredPersonId;
  String? deviceId;
  String? deviceToken;
  bool consentActive = false;
  bool _loaded = false;

  bool get isPaired =>
      monitoredPersonId != null &&
      monitoredPersonId!.isNotEmpty &&
      deviceId != null &&
      deviceId!.isNotEmpty &&
      deviceToken != null &&
      deviceToken!.isNotEmpty;

  /// Datos de pairing creados por una versión anterior que no persistía el
  /// token. Se conservan para informar al usuario, pero no habilitan telemetría.
  bool get requiresRepairing =>
      monitoredPersonId != null &&
      monitoredPersonId!.isNotEmpty &&
      deviceId != null &&
      deviceId!.isNotEmpty &&
      (deviceToken == null || deviceToken!.isEmpty);

  /// Rehidrata el estado persistido. Idempotente: solo lee la primera vez.
  /// Debe llamarse al abrir la pantalla MONITORED. Los fallos de almacenamiento
  /// (p. ej. Web sin storage) se ignoran y se conserva el estado en memoria.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      monitoredPersonId = prefs.getString(_kPersonId);
      deviceId = prefs.getString(_kDeviceId);
      deviceToken = prefs.getString(_kDeviceToken);
      consentActive = prefs.getBool(_kConsent) ?? false;
    } catch (_) {
      // almacenamiento no disponible: se mantiene el estado en memoria
    }
    _loaded = true;
  }

  Future<void> setPairing({
    required String personId,
    required String deviceId,
    required String deviceToken,
  }) async {
    monitoredPersonId = personId;
    this.deviceId = deviceId;
    this.deviceToken = deviceToken;
    consentActive = false;
    _loaded = true;
    await _persist();
  }

  void setConsentActive(bool active) {
    consentActive = active;
    _persist();
  }

  void clear() {
    monitoredPersonId = null;
    deviceId = null;
    deviceToken = null;
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
      if (deviceToken == null) {
        await prefs.remove(_kDeviceToken);
      } else {
        await prefs.setString(_kDeviceToken, deviceToken!);
      }
      await prefs.setBool(_kConsent, consentActive);
    } catch (_) {
      // se ignoran fallos de persistencia (p. ej. Web sin storage)
    }
  }

  @visibleForTesting
  void resetInMemoryForTests() {
    monitoredPersonId = null;
    deviceId = null;
    deviceToken = null;
    consentActive = false;
    _loaded = false;
  }
}

/// Versión de política GDPR según idioma activo (spec §6.2 / ADR-08).
String consentPolicyVersion(String languageCode) => '1.0-$languageCode';
