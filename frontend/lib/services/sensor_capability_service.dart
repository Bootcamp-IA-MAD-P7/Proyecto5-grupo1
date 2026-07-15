import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

/// Result of an IMU availability probe — RF-40 / T4e.1.
class ImuCapabilityResult {
  const ImuCapabilityResult({
    required this.accelerometerAvailable,
    required this.gyroscopeAvailable,
  });

  final bool accelerometerAvailable;
  final bool gyroscopeAvailable;

  bool get isFullyAvailable =>
      accelerometerAvailable && gyroscopeAvailable;
}

typedef AccelerometerProbe = Stream<AccelerometerEvent> Function({
  required Duration samplingPeriod,
});

typedef GyroscopeProbe = Stream<GyroscopeEvent> Function({
  required Duration samplingPeriod,
});

/// Probes accelerometer + gyroscope before pairing/consent/monitoring.
class SensorCapabilityService {
  SensorCapabilityService({
    this.probeTimeout = const Duration(seconds: 3),
    AccelerometerProbe? accelerometerProbe,
    GyroscopeProbe? gyroscopeProbe,
  })  : _accelerometerProbe =
            accelerometerProbe ?? accelerometerEventStream,
        _gyroscopeProbe = gyroscopeProbe ?? gyroscopeEventStream;

  final Duration probeTimeout;
  final AccelerometerProbe _accelerometerProbe;
  final GyroscopeProbe _gyroscopeProbe;

  Future<ImuCapabilityResult> checkImuAvailability() async {
    final accelerometerAvailable = await _probeSensor<AccelerometerEvent>(
      () => _accelerometerProbe(
        samplingPeriod: SensorInterval.normalInterval,
      ),
    );
    final gyroscopeAvailable = await _probeSensor<GyroscopeEvent>(
      () => _gyroscopeProbe(
        samplingPeriod: SensorInterval.normalInterval,
      ),
    );

    return ImuCapabilityResult(
      accelerometerAvailable: accelerometerAvailable,
      gyroscopeAvailable: gyroscopeAvailable,
    );
  }

  Future<bool> _probeSensor<T>(Stream<T> Function() streamFactory) async {
    StreamSubscription<T>? subscription;
    final ready = Completer<void>();

    try {
      subscription = streamFactory().listen(
        (_) {
          if (!ready.isCompleted) {
            ready.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!ready.isCompleted) {
            ready.completeError(error, stackTrace);
          }
        },
        cancelOnError: true,
      );
      await ready.future.timeout(probeTimeout);
      return true;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    } finally {
      await subscription?.cancel();
    }
  }
}
