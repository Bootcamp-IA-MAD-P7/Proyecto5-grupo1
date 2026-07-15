import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sentilife/services/sensor_capability_service.dart';

void main() {
  group('SensorCapabilityService', () {
    test('returns fully available when both sensors emit', () async {
      final service = SensorCapabilityService(
        probeTimeout: const Duration(milliseconds: 200),
        accelerometerProbe: ({required samplingPeriod}) => Stream.value(
          AccelerometerEvent(1, 2, 3, DateTime.now()),
        ),
        gyroscopeProbe: ({required samplingPeriod}) => Stream.value(
          GyroscopeEvent(0.1, 0.2, 0.3, DateTime.now()),
        ),
      );

      final result = await service.checkImuAvailability();

      expect(result.accelerometerAvailable, isTrue);
      expect(result.gyroscopeAvailable, isTrue);
      expect(result.isFullyAvailable, isTrue);
    });

    test('marks accelerometer missing on timeout', () async {
      final service = SensorCapabilityService(
        probeTimeout: const Duration(milliseconds: 50),
        accelerometerProbe: ({required samplingPeriod}) => const Stream.empty(),
        gyroscopeProbe: ({required samplingPeriod}) => Stream.value(
          GyroscopeEvent(0.1, 0.2, 0.3, DateTime.now()),
        ),
      );

      final result = await service.checkImuAvailability();

      expect(result.accelerometerAvailable, isFalse);
      expect(result.gyroscopeAvailable, isTrue);
      expect(result.isFullyAvailable, isFalse);
    });

    test('marks gyroscope missing on stream error', () async {
      final service = SensorCapabilityService(
        probeTimeout: const Duration(milliseconds: 200),
        accelerometerProbe: ({required samplingPeriod}) => Stream.value(
          AccelerometerEvent(1, 2, 3, DateTime.now()),
        ),
        gyroscopeProbe: ({required samplingPeriod}) =>
            Stream.error(StateError('no gyro')),
      );

      final result = await service.checkImuAvailability();

      expect(result.accelerometerAvailable, isTrue);
      expect(result.gyroscopeAvailable, isFalse);
      expect(result.isFullyAvailable, isFalse);
    });
  });
}
