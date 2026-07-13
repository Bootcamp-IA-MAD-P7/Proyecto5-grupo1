import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../config/window_contract.dart';
import '../models/prediction_result.dart';

class SensorCaptureService {
  SensorCaptureService();

  final StreamController<SensorSnapshot> _controller =
      StreamController<SensorSnapshot>.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Timer? _samplingTimer;

  AccelerometerEvent? _lastAccelerometer;
  GyroscopeEvent? _lastGyroscope;
  bool _running = false;
  bool _disposed = false;

  Stream<SensorSnapshot> get snapshots => _controller.stream;

  bool get isRunning => _running;

  void start() {
    if (_disposed || _running) return;

    final samplingPeriod = Duration(
      microseconds:
          Duration.microsecondsPerSecond ~/ WindowContract.sampleRateHz,
    );

    StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
    StreamSubscription<GyroscopeEvent>? gyroscopeSubscription;

    try {
      accelerometerSubscription =
          accelerometerEventStream(samplingPeriod: samplingPeriod).listen(
            (event) => _lastAccelerometer = event,
            onError: _handleSensorError,
            cancelOnError: false,
          );

      gyroscopeSubscription =
          gyroscopeEventStream(samplingPeriod: samplingPeriod).listen(
            (event) => _lastGyroscope = event,
            onError: _handleSensorError,
            cancelOnError: false,
          );

      _accelerometerSubscription = accelerometerSubscription;
      _gyroscopeSubscription = gyroscopeSubscription;
      _samplingTimer = Timer.periodic(samplingPeriod, (_) => _emitIfReady());
      _running = true;
    } catch (error, stackTrace) {
      _handleSensorError(error, stackTrace);
      if (accelerometerSubscription != null) {
        unawaited(accelerometerSubscription.cancel());
      }
      if (gyroscopeSubscription != null) {
        unawaited(gyroscopeSubscription.cancel());
      }
      _accelerometerSubscription = null;
      _gyroscopeSubscription = null;
      _samplingTimer = null;
      _lastAccelerometer = null;
      _lastGyroscope = null;
      _running = false;
    }
  }

  Future<void> stop() async {
    if (!_running) return;

    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _samplingTimer?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _samplingTimer = null;
    _lastAccelerometer = null;
    _lastGyroscope = null;
    _running = false;
  }

  Future<void> dispose() async {
    if (_disposed) return;

    await stop();
    _disposed = true;
    await _controller.close();
  }

  void _emitIfReady() {
    if (_disposed || _controller.isClosed) return;

    final accelerometer = _lastAccelerometer;
    final gyroscope = _lastGyroscope;
    if (accelerometer == null || gyroscope == null) return;

    _controller.add(
      SensorSnapshot(
        accelX: accelerometer.x,
        accelY: accelerometer.y,
        accelZ: accelerometer.z,
        gyroX: _radiansToDegrees(gyroscope.x),
        gyroY: _radiansToDegrees(gyroscope.y),
        gyroZ: _radiansToDegrees(gyroscope.z),
        // Contexto opcional definido en spec §6.3/RF-10. Hasta integrar
        // sensores específicos, 0.0 representa "no disponible".
        heartRate: 0.0,
        roomTemp: 0.0,
        roomLight: 0.0,
      ),
    );
  }

  double _radiansToDegrees(double radians) => radians * 180 / math.pi;

  void _handleSensorError(Object error, StackTrace stackTrace) {
    debugPrint('SensorCaptureService error: $error');
  }
}
