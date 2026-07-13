import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'device_id_service.dart';
import 'devices_service.dart';
import 'session_manager.dart';

/// Registra el token FCM del cuidador en el backend (T2.22 / RF-27).
class PushRegistrationService {
  PushRegistrationService({
    DevicesService? devicesService,
    DeviceIdService? deviceIdService,
  })  : _devicesService = devicesService ?? DevicesService(),
        _deviceIdService = deviceIdService ?? DeviceIdService();

  final DevicesService _devicesService;
  final DeviceIdService _deviceIdService;

  static StreamSubscription<String>? _refreshSub;

  @visibleForTesting
  static Future<String?> Function()? fcmTokenOverride;

  /// Tras login CAREGIVER: obtiene token FCM y llama POST /devices/push-token.
  /// Fallos no bloquean la navegación (best-effort).
  Future<void> registerForCaregiver({required String locale}) async {
    final user = SessionManager().currentUser;
    if (user == null || user.role != UserRole.caregiver) return;

    final fcmToken = await _resolveFcmToken();
    if (fcmToken == null || fcmToken.isEmpty) return;

    await _registerToken(fcmToken: fcmToken, locale: locale);
  }

  /// Renueva el token en backend cuando FCM lo rota (RF-27).
  void ensureTokenRefreshListener() {
    if (_refreshSub != null || fcmTokenOverride != null) return;

    try {
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async {
          final user = SessionManager().currentUser;
          if (user?.role != UserRole.caregiver) return;
          try {
            await _registerToken(fcmToken: token, locale: user!.locale);
          } catch (_) {}
        },
      );
    } catch (_) {}
  }

  Future<void> _registerToken({
    required String fcmToken,
    required String locale,
  }) async {
    final deviceId = await _deviceIdService.getStableDeviceId();
    await _devicesService.registerPushToken(
      fcmToken: fcmToken,
      deviceId: deviceId,
      locale: locale,
    );
  }

  Future<String?> _resolveFcmToken() async {
    if (fcmTokenOverride != null) return fcmTokenOverride!();
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void resetForTests() {
    fcmTokenOverride = null;
    _refreshSub?.cancel();
    _refreshSub = null;
  }
}
