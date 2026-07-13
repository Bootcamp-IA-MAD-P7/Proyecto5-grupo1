import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Opciones Firebase para builds sin `google-services.json` local.
/// En CI se escribe `android/app/google-services.json` desde secrets.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: ''),
      appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: ''),
      messagingSenderId: String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '',
      ),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    );
  }

  static bool get hasExplicitOptions {
    final o = currentPlatform;
    return o.apiKey.isNotEmpty &&
        o.appId.isNotEmpty &&
        o.messagingSenderId.isNotEmpty &&
        o.projectId.isNotEmpty;
  }
}
