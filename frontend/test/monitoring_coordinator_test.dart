import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/models/prediction_result.dart';
import 'package:sentilife/models/telemetry_window.dart';
import 'package:sentilife/services/monitoring_coordinator.dart';
import 'package:sentilife/services/monitoring_foreground_bridge.dart';
import 'package:sentilife/services/sensor_capture_service.dart';
import 'package:sentilife/services/sliding_window_builder.dart';
import 'package:sentilife/services/telemetry_pipeline_service.dart';
import 'package:sentilife/services/telemetry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonitoringCoordinator lifecycle', () {
    test('start activates pipeline and foreground bridge', () async {
      final sensor = _FakeSensorCaptureService();
      final foreground = _FakeForegroundBridge();
      final coordinator = MonitoringCoordinator(
        pipeline: TelemetryPipelineService(
          sensorCaptureService: sensor,
          windowBuilder: _FakeSlidingWindowBuilder(),
          telemetryService: _FakeTelemetryService(),
        ),
        foregroundBridge: foreground,
      );

      await coordinator.start(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
      );

      expect(coordinator.isMonitoring, isTrue);
      expect(foreground.startCount, 1);
      expect(sensor.startCount, 1);

      await coordinator.stop();
      expect(coordinator.isMonitoring, isFalse);
      expect(foreground.stopCount, 1);
    });

    test('notifies listeners when prediction arrives', () async {
      final sensor = _FakeSensorCaptureService();
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensor,
        windowBuilder: _FakeSlidingWindowBuilder(emitWindow: true),
        telemetryService: _FakeTelemetryService(),
      );
      final coordinator = MonitoringCoordinator(
        pipeline: pipeline,
        foregroundBridge: _FakeForegroundBridge(),
      );

      var notifications = 0;
      coordinator.addListener(() => notifications++);

      await coordinator.start(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
      );
      sensor.emit(_snapshot());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(coordinator.lastPrediction, isNotNull);
      expect(coordinator.lastWindowAt, isNotNull);
      expect(notifications, greaterThan(0));

      await coordinator.shutdown();
    });

    test('dispose stops monitoring safely', () async {
      final coordinator = MonitoringCoordinator(
        pipeline: TelemetryPipelineService(
          sensorCaptureService: _FakeSensorCaptureService(),
          windowBuilder: _FakeSlidingWindowBuilder(),
          telemetryService: _FakeTelemetryService(),
        ),
        foregroundBridge: _FakeForegroundBridge(),
      );

      await coordinator.start(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
      );
      await coordinator.shutdown();

      expect(coordinator.isMonitoring, isFalse);
    });
  });
}

class _FakeForegroundBridge extends MonitoringForegroundBridge {
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> start({String title = 'SentiLife', String body = 'Monitorizando...'}) async {
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _FakeSensorCaptureService extends SensorCaptureService {
  int startCount = 0;
  final _controller = StreamController<SensorSnapshot>.broadcast();

  @override
  Stream<SensorSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> start() async {
    startCount++;
  }

  @override
  Future<void> stop() async {}

  void emit(SensorSnapshot snapshot) => _controller.add(snapshot);
}

class _FakeSlidingWindowBuilder extends SlidingWindowBuilder {
  _FakeSlidingWindowBuilder({this.emitWindow = false});

  final bool emitWindow;

  @override
  TelemetryWindow? add(SensorSnapshot snapshot, {DateTime? capturedAt}) {
    if (!emitWindow) return null;
    final now = DateTime.now().toUtc();
    return TelemetryWindow(
      windowStart: now,
      windowEnd: now.add(const Duration(milliseconds: 2500)),
      sampleRateHz: 50,
      samples: {
        for (final signal in ['accX', 'accY', 'accZ', 'gyroX', 'gyroY', 'gyroZ'])
          signal: List<double>.filled(125, 1.0),
      },
      context: const {},
    );
  }
}

class _FakeTelemetryService extends TelemetryService {
  @override
  Future<WindowPrediction> sendWindow({
    required String monitoredPersonId,
    required String deviceId,
    required String deviceToken,
    required DateTime windowStart,
    required DateTime windowEnd,
    required int sampleRateHz,
    required Map<String, List<double>> samples,
    Map<String, dynamic>? context,
  }) async {
    return WindowPrediction(
      windowId: 'win-test',
      fallDetected: false,
      confidence: 0.1,
      modelVersion: 'test',
      latencyMs: 1,
    );
  }
}

SensorSnapshot _snapshot() => SensorSnapshot(
      accelX: 0.1,
      accelY: 9.8,
      accelZ: 0.2,
      gyroX: 1.0,
      gyroY: 0.5,
      gyroZ: 0.3,
      heartRate: 0,
      roomTemp: 0,
      roomLight: 0,
    );
