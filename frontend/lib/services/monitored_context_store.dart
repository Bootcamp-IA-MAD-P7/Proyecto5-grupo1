import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado local del perfil MONITORED: persona vinculada + consentimiento.
///
/// T2.21 (pairing) escribe [monitoredPersonId] y [deviceId].
/// T2.20 marca [consentActive] tras `POST /{id}/consent` exitoso.
/// T2.29 persiste el pairing en disco para que sobreviva al reinicio de la app.
/// T2c.10 — claves namespaced por [userId] (ADR-12 / RF-38).
class MonitoredContextStore {
  static final MonitoredContextStore _instance = MonitoredContextStore._();
  factory MonitoredContextStore() => _instance;
  MonitoredContextStore._();

  static const _legacyPersonId = 'monitored_person_id';
  static const _legacyDeviceId = 'monitored_device_id';
  static const _legacyDeviceToken = 'monitored_device_token';
  static const _legacyConsent = 'monitored_consent_active';

  String? _userId;
  String? monitoredPersonId;
  String? deviceId;
  String? deviceToken;
  bool consentActive = false;
  bool _loaded = false;

  /// Binds subsequent [load]/[clear]/[setPairing] to this account namespace.
  void bindUser(String userId) {
    if (_userId == userId && _loaded) return;
    final previousUser = _userId;
    _userId = userId;
    if (previousUser != null && previousUser != userId) {
      _loaded = false;
      monitoredPersonId = null;
      deviceId = null;
      deviceToken = null;
      consentActive = false;
    } else if (!_loaded) {
      // Same account on cold start: [load] hydrates from disk — do not wipe.
      _loaded = false;
    }
  }

  bool get isPaired =>
      monitoredPersonId != null &&
      monitoredPersonId!.isNotEmpty &&
      deviceId != null &&
      deviceId!.isNotEmpty &&
      deviceToken != null &&
      deviceToken!.isNotEmpty;

  bool get requiresRepairing =>
      monitoredPersonId != null &&
      monitoredPersonId!.isNotEmpty &&
      deviceId != null &&
      deviceId!.isNotEmpty &&
      (deviceToken == null || deviceToken!.isEmpty);

  String _requireUserId() {
    final id = _userId;
    if (id == null || id.isEmpty) {
      throw StateError('MonitoredContextStore.bindUser() must be called first');
    }
    return id;
  }

  String _kPersonId() => 'ctx_${_requireUserId()}_person_id';
  String _kDeviceId() => 'ctx_${_requireUserId()}_device_id';
  String _kDeviceToken() => 'ctx_${_requireUserId()}_device_token';
  String _kConsent() => 'ctx_${_requireUserId()}_consent_active';

  Future<void> load() async {
    if (_loaded) return;
    _requireUserId();
    try {
      final prefs = await SharedPreferences.getInstance();
      monitoredPersonId = prefs.getString(_kPersonId());
      deviceId = prefs.getString(_kDeviceId());
      deviceToken = prefs.getString(_kDeviceToken());
      consentActive = prefs.getBool(_kConsent()) ?? false;

      if (!_hasAnyNamespacedData(prefs) && _hasLegacyGlobalData(prefs)) {
        await _migrateLegacyGlobal(prefs);
      }
    } catch (_) {
      // almacenamiento no disponible: se mantiene el estado en memoria
    }
    _loaded = true;
  }

  bool _hasAnyNamespacedData(SharedPreferences prefs) =>
      prefs.containsKey(_kPersonId()) ||
      prefs.containsKey(_kDeviceId()) ||
      prefs.containsKey(_kDeviceToken()) ||
      prefs.containsKey(_kConsent());

  bool _hasLegacyGlobalData(SharedPreferences prefs) =>
      prefs.containsKey(_legacyPersonId) ||
      prefs.containsKey(_legacyDeviceId) ||
      prefs.containsKey(_legacyDeviceToken) ||
      prefs.containsKey(_legacyConsent);

  Future<void> _migrateLegacyGlobal(SharedPreferences prefs) async {
    monitoredPersonId ??= prefs.getString(_legacyPersonId);
    deviceId ??= prefs.getString(_legacyDeviceId);
    deviceToken ??= prefs.getString(_legacyDeviceToken);
    consentActive = prefs.getBool(_legacyConsent) ?? consentActive;
    await _persist();
    await prefs.remove(_legacyPersonId);
    await prefs.remove(_legacyDeviceId);
    await prefs.remove(_legacyDeviceToken);
    await prefs.remove(_legacyConsent);
  }

  Future<void> setPairing({
    required String personId,
    required String deviceId,
    required String deviceToken,
    bool resetConsent = true,
  }) async {
    _requireUserId();
    monitoredPersonId = personId;
    this.deviceId = deviceId;
    this.deviceToken = deviceToken;
    if (resetConsent) {
      consentActive = false;
    }
    _loaded = true;
    await _persist();
  }

  Future<void> setConsentActive(bool active) async {
    _requireUserId();
    consentActive = active;
    await _persist();
  }

  Future<void> clear() async {
    if (_userId == null) return;
    monitoredPersonId = null;
    deviceId = null;
    deviceToken = null;
    consentActive = false;
    _loaded = true;
    await _persist();
  }

  Future<void> _persist() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (monitoredPersonId == null) {
        await prefs.remove(_kPersonId());
      } else {
        await prefs.setString(_kPersonId(), monitoredPersonId!);
      }
      if (deviceId == null) {
        await prefs.remove(_kDeviceId());
      } else {
        await prefs.setString(_kDeviceId(), deviceId!);
      }
      if (deviceToken == null) {
        await prefs.remove(_kDeviceToken());
      } else {
        await prefs.setString(_kDeviceToken(), deviceToken!);
      }
      await prefs.setBool(_kConsent(), consentActive);
    } catch (_) {
      // se ignoran fallos de persistencia (p. ej. Web sin storage)
    }
  }

  @visibleForTesting
  void resetInMemoryForTests() {
    _userId = null;
    monitoredPersonId = null;
    deviceId = null;
    deviceToken = null;
    consentActive = false;
    _loaded = false;
  }
}

/// Versión de política GDPR según idioma activo (spec §6.2 / ADR-08).
String consentPolicyVersion(String languageCode) => '1.0-$languageCode';
