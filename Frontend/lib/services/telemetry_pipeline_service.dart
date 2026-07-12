import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/prediction_result.dart';
import '../models/telemetry_window.dart';
import 'sensor_capture_service.dart';
import 'sliding_window_builder.dart';
import 'telemetry_service.dart';

class TelemetryPipelineService {
  TelemetryPipelineService({
    SensorCaptureService? sensorCaptureService,
    SlidingWindowBuilder? windowBuilder,
    TelemetryService? telemetryService,
  }) : _sensorCaptureService = sensorCaptureService ?? SensorCaptureService(),
       _windowBuilder = windowBuilder ?? SlidingWindowBuilder(),
       _telemetryService = telemetryService ?? TelemetryService();

  final SensorCaptureService _sensorCaptureService;
  final SlidingWindowBuilder _windowBuilder;
  final TelemetryService _telemetryService;
  final StreamController<WindowPrediction> _predictionsController =
      StreamController<WindowPrediction>.broadcast();
  final Queue<_QueuedTelemetryWindow> _pendingWindows =
      Queue<_QueuedTelemetryWindow>();

  StreamSubscription<SensorSnapshot>? _snapshotSubscription;
  String? _monitoredPersonId;
  String? _deviceId;
  bool _isRunning = false;
  bool _isDisposed = false;
  bool _isSending = false;

  Stream<WindowPrediction> get predictions => _predictionsController.stream;

  bool get isRunning => _isRunning;

  Future<void> startMonitoring({
    required String monitoredPersonId,
    required String deviceId,
  }) async {
    if (_isDisposed || _isRunning) {
      return;
    }

    _monitoredPersonId = monitoredPersonId;
    _deviceId = deviceId;
    _windowBuilder.reset();

    _snapshotSubscription = _sensorCaptureService.snapshots.listen(
      _handleSnapshot,
      onError: _handleCaptureError,
      cancelOnError: false,
    );

    try {
      _sensorCaptureService.start();
      _isRunning = true;
    } catch (error, stackTrace) {
      _handleCaptureError(error, stackTrace);
      try {
        await _snapshotSubscription?.cancel();
      } catch (cancelError, cancelStackTrace) {
        _handleCaptureError(cancelError, cancelStackTrace);
      } finally {
        _snapshotSubscription = null;
        _clearMonitoringState();
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isRunning && _snapshotSubscription == null) {
      _clearMonitoringState();
      return;
    }

    _isRunning = false;
    Object? stopError;
    StackTrace? stopStackTrace;

    try {
      await _snapshotSubscription?.cancel();
    } catch (error, stackTrace) {
      stopError = error;
      stopStackTrace = stackTrace;
    }

    try {
      await _sensorCaptureService.stop();
    } catch (error, stackTrace) {
      stopError ??= error;
      stopStackTrace ??= stackTrace;
    } finally {
      _snapshotSubscription = null;
      _clearMonitoringState();
    }

    if (stopError != null && stopStackTrace != null) {
      Error.throwWithStackTrace(stopError, stopStackTrace);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    Object? disposeError;
    StackTrace? disposeStackTrace;

    try {
      await stopMonitoring();
    } catch (error, stackTrace) {
      disposeError = error;
      disposeStackTrace = stackTrace;
    }

    try {
      await _sensorCaptureService.dispose();
    } catch (error, stackTrace) {
      disposeError ??= error;
      disposeStackTrace ??= stackTrace;
    } finally {
      try {
        await _snapshotSubscription?.cancel();
      } catch (error, stackTrace) {
        disposeError ??= error;
        disposeStackTrace ??= stackTrace;
      } finally {
        _snapshotSubscription = null;
        _clearMonitoringState();
        if (!_predictionsController.isClosed) {
          await _predictionsController.close();
        }
      }
    }

    if (disposeError != null && disposeStackTrace != null) {
      Error.throwWithStackTrace(disposeError, disposeStackTrace);
    }
  }

  void _handleSnapshot(SensorSnapshot snapshot) {
    final window = _windowBuilder.add(snapshot);
    if (window == null) {
      return;
    }

    final monitoredPersonId = _monitoredPersonId;
    final deviceId = _deviceId;
    if (monitoredPersonId == null || deviceId == null) {
      return;
    }

    _pendingWindows.addLast(
      _QueuedTelemetryWindow(
        window: window,
        monitoredPersonId: monitoredPersonId,
        deviceId: deviceId,
      ),
    );
    unawaited(_drainPendingWindows());
  }

  Future<void> _drainPendingWindows() async {
    if (_isSending ||
        !_isRunning ||
        _pendingWindows.isEmpty ||
        _predictionsController.isClosed) {
      return;
    }

    _isSending = true;
    try {
      while (_isRunning &&
          _pendingWindows.isNotEmpty &&
          !_predictionsController.isClosed) {
        final pendingWindow = _pendingWindows.first;
        try {
          final prediction = await _telemetryService.sendWindow(
            monitoredPersonId: pendingWindow.monitoredPersonId,
            deviceId: pendingWindow.deviceId,
            windowStart: pendingWindow.window.windowStart,
            windowEnd: pendingWindow.window.windowEnd,
            sampleRateHz: pendingWindow.window.sampleRateHz,
            samples: pendingWindow.window.samples,
            context: pendingWindow.window.context,
          );

          _pendingWindows.removeFirst();
          if (_isRunning && !_predictionsController.isClosed) {
            _predictionsController.add(prediction);
          }
        } catch (error, stackTrace) {
          debugPrint('TelemetryPipelineService sendWindow error: $error');
          debugPrintStack(stackTrace: stackTrace);
          break;
        }
      }
    } finally {
      _isSending = false;
    }
  }

  void _handleCaptureError(Object error, StackTrace stackTrace) {
    debugPrint('TelemetryPipelineService capture error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  void _clearMonitoringState() {
    _isRunning = false;
    _isSending = false;
    _pendingWindows.clear();
    _windowBuilder.reset();
    _monitoredPersonId = null;
    _deviceId = null;
  }
}

class _QueuedTelemetryWindow {
  const _QueuedTelemetryWindow({
    required this.window,
    required this.monitoredPersonId,
    required this.deviceId,
  });

  final TelemetryWindow window;
  final String monitoredPersonId;
  final String deviceId;
}
