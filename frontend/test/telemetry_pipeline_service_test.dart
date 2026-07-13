import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/models/prediction_result.dart';
import 'package:sentilife/models/telemetry_window.dart';
import 'package:sentilife/services/sensor_capture_service.dart';
import 'package:sentilife/services/sliding_window_builder.dart';
import 'package:sentilife/services/telemetry_pipeline_service.dart';
import 'package:sentilife/services/telemetry_service.dart';

void main() {
  group('TelemetryPipelineService', () {
    test('startMonitoring starts the pipeline once', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: _FakeSlidingWindowBuilder(),
        telemetryService: _FakeTelemetryService(),
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );

      expect(pipeline.isRunning, isTrue);
      expect(sensorCaptureService.startCount, 1);
    });

    test('duplicate starts are ignored safely', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: _FakeSlidingWindowBuilder(),
        telemetryService: _FakeTelemetryService(),
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      await pipeline.startMonitoring(
        monitoredPersonId: 'person-2',
        deviceId: 'device-2',
        deviceToken: 'device-token-2',
      );

      expect(pipeline.isRunning, isTrue);
      expect(sensorCaptureService.startCount, 1);
    });

    test('incoming snapshots are forwarded to SlidingWindowBuilder', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final windowBuilder = _FakeSlidingWindowBuilder();
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: _FakeTelemetryService(),
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      final snapshot = _snapshot();
      sensorCaptureService.emit(snapshot);
      await Future<void>.delayed(Duration.zero);

      expect(windowBuilder.addCount, 1);
      expect(windowBuilder.lastSnapshot, same(snapshot));
    });

    test(
      'a generated TelemetryWindow is sent through TelemetryService',
      () async {
        final sensorCaptureService = _FakeSensorCaptureService();
        final windowBuilder = _FakeSlidingWindowBuilder()
          ..outputs.add(_window());
        final telemetryService = _FakeTelemetryService()
          ..responses.add(_prediction());
        final pipeline = TelemetryPipelineService(
          sensorCaptureService: sensorCaptureService,
          windowBuilder: windowBuilder,
          telemetryService: telemetryService,
        );

        await pipeline.startMonitoring(
          monitoredPersonId: 'person-1',
          deviceId: 'device-1',
          deviceToken: 'device-token-1',
        );
        sensorCaptureService.emit(_snapshot());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(telemetryService.sendCount, 1);
        expect(telemetryService.lastMonitoredPersonId, 'person-1');
        expect(telemetryService.lastDeviceId, 'device-1');
        expect(telemetryService.lastDeviceToken, 'device-token-1');
        expect(telemetryService.lastWindow, isNotNull);
      },
    );

    test('WindowPrediction is emitted', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final windowBuilder = _FakeSlidingWindowBuilder()..outputs.add(_window());
      final prediction = _prediction(confidence: 0.91);
      final telemetryService = _FakeTelemetryService()
        ..responses.add(prediction);
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: telemetryService,
      );

      final expectation = expectLater(
        pipeline.predictions,
        emits(same(prediction)),
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      sensorCaptureService.emit(_snapshot());

      await expectation;
    });

    test(
      'TelemetryService exceptions do not close the predictions stream',
      () async {
        final sensorCaptureService = _FakeSensorCaptureService();
        final windowBuilder = _FakeSlidingWindowBuilder()
          ..outputs.add(_window())
          ..outputs.add(_window());
        final prediction = _prediction(confidence: 0.73);
        final telemetryService = _FakeTelemetryService()
          ..responses.add(Exception('send failed'))
          ..responses.add(prediction);
        final pipeline = TelemetryPipelineService(
          sensorCaptureService: sensorCaptureService,
          windowBuilder: windowBuilder,
          telemetryService: telemetryService,
        );

        final expectation = expectLater(
          pipeline.predictions,
          emits(same(prediction)),
        );

        await pipeline.startMonitoring(
          monitoredPersonId: 'person-1',
          deviceId: 'device-1',
          deviceToken: 'device-token-1',
        );
        sensorCaptureService.emit(_snapshot());
        await Future<void>.delayed(Duration.zero);
        sensorCaptureService.emit(_snapshot());

        await expectation;
        expect(pipeline.isRunning, isTrue);
        expect(telemetryService.sendCount, 3);
      },
    );

    test('stopMonitoring cancels capture and resets state', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final windowBuilder = _FakeSlidingWindowBuilder();
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: _FakeTelemetryService(),
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      await pipeline.stopMonitoring();

      expect(pipeline.isRunning, isFalse);
      expect(sensorCaptureService.stopCount, 1);
      expect(windowBuilder.resetCount, 2);
    });

    test('dispose releases resources', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: _FakeSlidingWindowBuilder(),
        telemetryService: _FakeTelemetryService(),
      );

      final expectation = expectLater(pipeline.predictions, emitsDone);

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      await pipeline.dispose();

      expect(pipeline.isRunning, isFalse);
      expect(sensorCaptureService.stopCount, 1);
      expect(sensorCaptureService.disposeCount, 1);
      await expectation;
    });

    test(
      'startMonitoring cleans state and rethrows when capture start fails',
      () async {
        final sensorCaptureService = _FakeSensorCaptureService()
          ..startError = StateError('start failed');
        final windowBuilder = _FakeSlidingWindowBuilder();
        final pipeline = TelemetryPipelineService(
          sensorCaptureService: sensorCaptureService,
          windowBuilder: windowBuilder,
          telemetryService: _FakeTelemetryService(),
        );

        await expectLater(
          pipeline.startMonitoring(
            monitoredPersonId: 'person-1',
            deviceId: 'device-1',
            deviceToken: 'device-token-1',
          ),
          throwsA(isA<StateError>()),
        );

        expect(pipeline.isRunning, isFalse);
        expect(sensorCaptureService.startCount, 1);
        expect(sensorCaptureService.hasListener, isFalse);
        expect(windowBuilder.resetCount, 2);
      },
    );

    test('dispose cleans state when stopMonitoring fails', () async {
      final sensorCaptureService = _FakeSensorCaptureService()
        ..stopError = StateError('stop failed');
      final windowBuilder = _FakeSlidingWindowBuilder();
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: _FakeTelemetryService(),
      );
      final expectation = expectLater(pipeline.predictions, emitsDone);

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );

      await expectLater(pipeline.dispose(), throwsA(isA<StateError>()));

      expect(pipeline.isRunning, isFalse);
      expect(sensorCaptureService.hasListener, isFalse);
      expect(sensorCaptureService.stopCount, 1);
      expect(sensorCaptureService.disposeCount, 1);
      expect(windowBuilder.resetCount, 3);
      await expectation;
    });

    test('snapshots are not processed after capture start fails', () async {
      final sensorCaptureService = _FakeSensorCaptureService()
        ..startError = StateError('start failed');
      final windowBuilder = _FakeSlidingWindowBuilder();
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: _FakeTelemetryService(),
      );

      await expectLater(
        pipeline.startMonitoring(
          monitoredPersonId: 'person-1',
          deviceId: 'device-1',
          deviceToken: 'device-token-1',
        ),
        throwsA(isA<StateError>()),
      );
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);

      expect(windowBuilder.addCount, 0);
      expect(sensorCaptureService.hasListener, isFalse);
    });

    test('failed send enqueues the window without losing it', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final window = _window(startSecond: 1);
      final windowBuilder = _FakeSlidingWindowBuilder()..outputs.add(window);
      final telemetryService = _FakeTelemetryService()
        ..responses.add(Exception('offline'));
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: telemetryService,
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(telemetryService.sendCount, 1);
      _expectSentWindows(telemetryService.sentWindows, [window]);
    });

    test(
      'a later window retries pending queue before sending the new one',
      () async {
        final sensorCaptureService = _FakeSensorCaptureService();
        final firstWindow = _window(startSecond: 1);
        final secondWindow = _window(startSecond: 2);
        final windowBuilder = _FakeSlidingWindowBuilder()
          ..outputs.add(firstWindow)
          ..outputs.add(secondWindow);
        final firstRetryPrediction = _prediction(windowId: 'first-retry');
        final secondPrediction = _prediction(windowId: 'second');
        final telemetryService = _FakeTelemetryService()
          ..responses.add(Exception('offline'))
          ..responses.add(firstRetryPrediction)
          ..responses.add(secondPrediction);
        final pipeline = TelemetryPipelineService(
          sensorCaptureService: sensorCaptureService,
          windowBuilder: windowBuilder,
          telemetryService: telemetryService,
        );

        final expectation = expectLater(
          pipeline.predictions,
          emitsInOrder([same(firstRetryPrediction), same(secondPrediction)]),
        );

        await pipeline.startMonitoring(
          monitoredPersonId: 'person-1',
          deviceId: 'device-1',
          deviceToken: 'device-token-1',
        );
        sensorCaptureService.emit(_snapshot());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        sensorCaptureService.emit(_snapshot());

        await expectation;
        _expectSentWindows(telemetryService.sentWindows, [
          firstWindow,
          firstWindow,
          secondWindow,
        ]);
      },
    );

    test('pending windows are retried in FIFO order', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final firstWindow = _window(startSecond: 1);
      final secondWindow = _window(startSecond: 2);
      final thirdWindow = _window(startSecond: 3);
      final windowBuilder = _FakeSlidingWindowBuilder()
        ..outputs.add(firstWindow)
        ..outputs.add(secondWindow)
        ..outputs.add(thirdWindow);
      final telemetryService = _FakeTelemetryService()
        ..responses.add(Exception('offline'))
        ..responses.add(_prediction(windowId: 'first'))
        ..responses.add(_prediction(windowId: 'second'))
        ..responses.add(_prediction(windowId: 'third'));
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: telemetryService,
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      _expectSentWindows(telemetryService.sentWindows, [
        firstWindow,
        firstWindow,
        secondWindow,
        thirdWindow,
      ]);
    });

    test('windows are not sent concurrently', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final firstWindow = _window(startSecond: 1);
      final secondWindow = _window(startSecond: 2);
      final firstResponse = Completer<WindowPrediction>();
      final windowBuilder = _FakeSlidingWindowBuilder()
        ..outputs.add(firstWindow)
        ..outputs.add(secondWindow);
      final telemetryService = _FakeTelemetryService()
        ..responses.add(firstResponse)
        ..responses.add(_prediction(windowId: 'second'));
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: telemetryService,
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);

      expect(telemetryService.sendCount, 1);
      expect(telemetryService.maxConcurrentSends, 1);

      firstResponse.complete(_prediction(windowId: 'first'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(telemetryService.sendCount, 2);
      expect(telemetryService.maxConcurrentSends, 1);
      _expectSentWindows(telemetryService.sentWindows, [
        firstWindow,
        secondWindow,
      ]);
    });

    test('a failed retry keeps the window at the front of the queue', () async {
      final sensorCaptureService = _FakeSensorCaptureService();
      final firstWindow = _window(startSecond: 1);
      final secondWindow = _window(startSecond: 2);
      final windowBuilder = _FakeSlidingWindowBuilder()
        ..outputs.add(firstWindow)
        ..outputs.add(secondWindow);
      final telemetryService = _FakeTelemetryService()
        ..responses.add(Exception('offline'))
        ..responses.add(Exception('still offline'));
      final pipeline = TelemetryPipelineService(
        sensorCaptureService: sensorCaptureService,
        windowBuilder: windowBuilder,
        telemetryService: telemetryService,
      );

      await pipeline.startMonitoring(
        monitoredPersonId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'device-token-1',
      );
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      sensorCaptureService.emit(_snapshot());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(telemetryService.sendCount, 2);
      _expectSentWindows(telemetryService.sentWindows, [
        firstWindow,
        firstWindow,
      ]);
    });
  });
}

class _FakeSensorCaptureService implements SensorCaptureService {
  final StreamController<SensorSnapshot> _controller =
      StreamController<SensorSnapshot>.broadcast();

  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  Object? startError;
  Object? stopError;
  Object? disposeError;
  bool _isRunning = false;

  @override
  Stream<SensorSnapshot> get snapshots => _controller.stream;

  @override
  bool get isRunning => _isRunning;

  bool get hasListener => _controller.hasListener;

  @override
  Future<void> start() async {
    startCount++;
    if (startError != null) {
      throw startError!;
    }
    _isRunning = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _isRunning = false;
    if (stopError != null) {
      throw stopError!;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _isRunning = false;
    if (disposeError != null) {
      throw disposeError!;
    }
    await _controller.close();
  }

  void emit(SensorSnapshot snapshot) {
    _controller.add(snapshot);
  }
}

class _FakeSlidingWindowBuilder implements SlidingWindowBuilder {
  final Queue<TelemetryWindow?> outputs = Queue<TelemetryWindow?>();
  int addCount = 0;
  int resetCount = 0;
  SensorSnapshot? lastSnapshot;

  @override
  TelemetryWindow? add(SensorSnapshot snapshot, {DateTime? capturedAt}) {
    addCount++;
    lastSnapshot = snapshot;
    return outputs.isEmpty ? null : outputs.removeFirst();
  }

  @override
  void reset() {
    resetCount++;
  }
}

class _FakeTelemetryService implements TelemetryService {
  final Queue<Object> responses = Queue<Object>();
  final List<TelemetryWindow> sentWindows = [];
  int sendCount = 0;
  int currentConcurrentSends = 0;
  int maxConcurrentSends = 0;
  String? lastMonitoredPersonId;
  String? lastDeviceId;
  String? lastDeviceToken;
  TelemetryWindow? lastWindow;

  @override
  Future<WindowPrediction> sendWindow({
    required String monitoredPersonId,
    required String deviceId,
    required String deviceToken,
    required DateTime windowStart,
    required DateTime windowEnd,
    required int sampleRateHz,
    required Map<String, List<double>> samples,
    Map<String, double>? context,
  }) async {
    sendCount++;
    currentConcurrentSends++;
    if (currentConcurrentSends > maxConcurrentSends) {
      maxConcurrentSends = currentConcurrentSends;
    }
    lastMonitoredPersonId = monitoredPersonId;
    lastDeviceId = deviceId;
    lastDeviceToken = deviceToken;
    lastWindow = TelemetryWindow(
      windowStart: windowStart,
      windowEnd: windowEnd,
      sampleRateHz: sampleRateHz,
      samples: samples,
      context: context,
    );
    sentWindows.add(lastWindow!);

    try {
      final response = responses.isEmpty
          ? _prediction()
          : responses.removeFirst();
      if (response is Exception) {
        throw response;
      }
      if (response is Completer<WindowPrediction>) {
        return await response.future;
      }
      return response as WindowPrediction;
    } finally {
      currentConcurrentSends--;
    }
  }

  @override
  Future<MonitoringStatusResponse> getStatus(String monitoredPersonId) {
    throw UnimplementedError();
  }
}

SensorSnapshot _snapshot() {
  return SensorSnapshot(
    accelX: 1,
    accelY: 2,
    accelZ: 3,
    gyroX: 4,
    gyroY: 5,
    gyroZ: 6,
    heartRate: 0,
    roomTemp: 0,
    roomLight: 0,
  );
}

TelemetryWindow _window({int startSecond = 0}) {
  final windowStart = DateTime.utc(2026, 1, 1, 12, 0, startSecond);
  final samples = List<double>.filled(125, 1);
  return TelemetryWindow(
    windowStart: windowStart,
    windowEnd: windowStart.add(const Duration(milliseconds: 2500)),
    sampleRateHz: 50,
    samples: {
      'accX': samples,
      'accY': samples,
      'accZ': samples,
      'gyroX': samples,
      'gyroY': samples,
      'gyroZ': samples,
    },
  );
}

WindowPrediction _prediction({
  String windowId = 'window-1',
  double confidence = 0.8,
}) {
  return WindowPrediction(
    windowId: windowId,
    fallDetected: false,
    confidence: confidence,
    modelVersion: 'test-model',
    latencyMs: 12,
  );
}

void _expectSentWindows(
  List<TelemetryWindow> actual,
  List<TelemetryWindow> expected,
) {
  expect(actual, hasLength(expected.length));

  for (var index = 0; index < expected.length; index++) {
    expect(actual[index].windowStart, expected[index].windowStart);
    expect(actual[index].windowEnd, expected[index].windowEnd);
    expect(actual[index].sampleRateHz, expected[index].sampleRateHz);
    expect(actual[index].samples, equals(expected[index].samples));
    expect(actual[index].context, equals(expected[index].context));
  }
}
