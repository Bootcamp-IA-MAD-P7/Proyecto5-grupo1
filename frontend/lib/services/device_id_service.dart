import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// ID estable por instalación para emparejamiento y telemetría (T2.21).
class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._();
  factory DeviceIdService() => _instance;
  DeviceIdService._();

  @visibleForTesting
  static String? testOverride;

  String? _cached;

  Future<String> getStableDeviceId() async {
    if (testOverride != null) return testOverride!;
    if (_cached != null && _cached!.isNotEmpty) return _cached!;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/sentilife_device_id');
    if (await file.exists()) {
      _cached = (await file.readAsString()).trim();
      if (_cached!.isNotEmpty) return _cached!;
    }

    final id = 'android-${_randomHex(32)}';
    await file.writeAsString(id);
    _cached = id;
    return id;
  }

  @visibleForTesting
  static void resetForTests() {
    testOverride = null;
    _instance._cached = null;
  }

  static String _randomHex(int length) {
    final random = Random.secure();
    const chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
