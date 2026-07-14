import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/push_alert_payload.dart';
import '../models/user.dart';
import '../screens/alert_detail_loader_screen.dart';
import 'push_notification_handler.dart';
import 'session_manager.dart';

/// Recepción FCM y navegación a detalle de alerta (T2.16 / SL-39).
class PushNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static String? pendingAlertId;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<RemoteMessage>? _openedSub;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _openedSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _storePendingAlert(initial);
    } catch (_) {}
  }

  /// Tras login CAREGIVER y con navigator listo, abre alerta pendiente.
  static Future<void> tryNavigateToPendingAlert() async {
    final alertId = pendingAlertId;
    if (alertId == null || alertId.isEmpty) return;

    final user = SessionManager().currentUser;
    if (user?.role != UserRole.caregiver) return;

    final navigated = await navigateToAlert(alertId);
    if (navigated) pendingAlertId = null;
  }

  static Future<bool> navigateToAlert(String alertId) async {
    if (alertId.isEmpty) return false;

    BuildContext? context;
    try {
      context = navigatorKey.currentContext;
    } catch (_) {
      pendingAlertId = alertId;
      return false;
    }

    if (context == null) {
      pendingAlertId = alertId;
      return false;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertDetailLoaderScreen(alertId: alertId),
      ),
    );
    return true;
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final payload = _parsePayload(message);
    if (payload == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) {
      pendingAlertId = payload.alertId;
      return;
    }

    final body = message.notification?.body ??
        (payload.personName != null
            ? 'Posible caída — ${payload.personName}'
            : 'Nueva alerta de caída');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => unawaited(navigateToAlert(payload.alertId)),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  static void _onNotificationTap(RemoteMessage message) {
    final payload = _parsePayload(message);
    if (payload == null) return;
    unawaited(navigateToAlert(payload.alertId));
  }

  static void _storePendingAlert(RemoteMessage message) {
    final payload = _parsePayload(message);
    if (payload == null) return;
    pendingAlertId = payload.alertId;
  }

  static PushAlertPayload? _parsePayload(RemoteMessage message) {
    if (message.data.isEmpty) return null;
    final payload = PushAlertPayload.fromData(
      Map<String, dynamic>.from(message.data),
    );
    if (!shouldAcceptPayload(payload)) return null;
    return payload;
  }

  /// Returns true when the push targets the active CAREGIVER session (T2c.10).
  @visibleForTesting
  static bool shouldAcceptPayload(PushAlertPayload payload) {
    if (!payload.isFallAlert || payload.alertId.isEmpty) return false;

    final user = SessionManager().currentUser;
    if (user == null || user.role != UserRole.caregiver) return false;

    final recipientId = payload.recipientUserId;
    if (recipientId != null &&
        recipientId.isNotEmpty &&
        recipientId != user.id) {
      return false;
    }
    return true;
  }

  @visibleForTesting
  static void resetForTests() {
    pendingAlertId = null;
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    _foregroundSub = null;
    _openedSub = null;
    _initialized = false;
  }
}
