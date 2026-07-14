import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android foreground service bridge — keeps the process alive during monitoring.
class MonitoringForegroundBridge {
  static const _channel = MethodChannel('com.sentilife.app/monitoring');

  bool _active = false;

  bool get isActive => _active;

  Future<void> start({String title = 'SentiLife', String body = 'Monitorizando...'}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('startForeground', {
        'title': title,
        'body': body,
      });
    }
    _active = true;
  }

  Future<void> stop() async {
    if (_active && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('stopForeground');
    }
    _active = false;
  }
}
