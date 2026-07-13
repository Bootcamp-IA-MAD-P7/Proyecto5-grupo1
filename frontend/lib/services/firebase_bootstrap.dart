import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_options.dart';
import 'push_notification_service.dart';
import 'push_registration_service.dart';

/// Inicializa Firebase + listeners FCM. Best-effort: no bloquea el arranque.
class FirebaseBootstrap {
  static bool initialized = false;

  static Future<void> initialize() async {
    if (initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        if (DefaultFirebaseOptions.hasExplicitOptions) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } else {
          // Config nativa embebida por google-services.json en build Android.
          await Firebase.initializeApp();
        }
      }
      initialized = true;
      PushRegistrationService().ensureTokenRefreshListener();
      await PushNotificationService.initialize();
      if (kDebugMode) debugPrint('[FCM] Firebase inicializado correctamente');
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[FCM] Firebase no disponible: $e\n'
          '  Local: source .env && bash scripts/setup-firebase.sh && make flutter-local',
        );
      }
    }
  }
}
