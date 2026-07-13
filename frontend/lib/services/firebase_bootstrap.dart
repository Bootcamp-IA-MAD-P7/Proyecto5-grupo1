import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_options.dart';
import 'push_notification_service.dart';
import 'push_registration_service.dart';

/// Inicializa Firebase + listeners FCM. Best-effort: no bloquea el arranque.
class FirebaseBootstrap {
  static bool initialized = false;

  /// True cuando push quedó deshabilitado de forma explícita (p. ej. Web sin
  /// opciones de Firebase). Permite a la UI comunicar el estado si hace falta.
  static bool pushDisabled = false;

  static Future<void> initialize() async {
    if (initialized) return;

    // Web requiere configuración explícita (config/firebase_options.dart).
    // Sin ella deshabilitamos push de forma explícita en vez de tragar el error.
    if (kIsWeb && !DefaultFirebaseOptions.hasExplicitOptions) {
      pushDisabled = true;
      if (kDebugMode) {
        debugPrint(
          '[FCM] Push deshabilitado en Web: faltan opciones de Firebase '
          '(config/firebase_options.dart). La app sigue funcionando sin '
          'notificaciones push.',
        );
      }
      return;
    }

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
      pushDisabled = true;
      if (kDebugMode) {
        debugPrint(
          '[FCM] Firebase no disponible: $e\n'
          '  Local: source .env && bash scripts/setup-firebase.sh && make flutter-local',
        );
      }
    }
  }
}
