import 'dart:async';

import 'package:flutter/foundation.dart';

import 'exceptions.dart';
import 'monitoring_foreground_bridge.dart';
import 'telemetry_pipeline_service.dart';
import 'telemetry_service.dart';

/// Orchestrates sensor monitoring lifecycle — ADR-12 / T2c.9.
class MonitoringCoordinator extends ChangeNotifier {
  MonitoringCoordinator({
    TelemetryPipelineService? pipeline,
    MonitoringForegroundBridge? foregroundBridge,
    void Function(TelemetryException error)? onTelemetryError,
    void Function(Object error)? onCaptureError,
  })  : _pipeline = pipeline ??
            TelemetryPipelineService(
              onTelemetryError: onTelemetryError,
              onCaptureError: onCaptureError,
            ),
        _foregroundBridge = foregroundBridge ?? MonitoringForegroundBridge();

  final TelemetryPipelineService _pipeline;
  final MonitoringForegroundBridge _foregroundBridge;

  StreamSubscription<WindowPrediction>? _predictionSub;
  bool _disposed = false;

  WindowPrediction? _lastPrediction;
  DateTime? _lastWindowAt;

  bool get isMonitoring => _pipeline.isRunning;
  WindowPrediction? get lastPrediction => _lastPrediction;
  DateTime? get lastWindowAt => _lastWindowAt;

  Future<void> start({
    required String monitoredPersonId,
    required String deviceId,
    required String deviceToken,
  }) async {
    if (_disposed || isMonitoring) return;

    _predictionSub = _pipeline.predictions.listen((prediction) {
      _lastPrediction = prediction;
      _lastWindowAt = DateTime.now();
      notifyListeners();
    });

    await _pipeline.startMonitoring(
      monitoredPersonId: monitoredPersonId,
      deviceId: deviceId,
      deviceToken: deviceToken,
    );

    await _foregroundBridge.start();
    notifyListeners();
  }

  Future<void> stop() async {
    await _predictionSub?.cancel();
    _predictionSub = null;
    await _pipeline.stopMonitoring();
    await _foregroundBridge.stop();
    notifyListeners();
  }

  Future<void> shutdown() async {
    if (_disposed) return;
    _disposed = true;
    await _predictionSub?.cancel();
    _predictionSub = null;
    await _pipeline.dispose();
    await _foregroundBridge.stop();
    notifyListeners();
  }

  @visibleForTesting
  TelemetryPipelineService get pipeline => _pipeline;
}
