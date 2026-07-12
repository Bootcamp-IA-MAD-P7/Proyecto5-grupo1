import '../config/window_contract.dart';
import '../models/prediction_result.dart';
import '../models/telemetry_window.dart';

class SlidingWindowBuilder {
  final List<_BufferedSnapshot> _buffer = [];
  double _hopCarry = 0;

  TelemetryWindow? add(SensorSnapshot snapshot, {DateTime? capturedAt}) {
    if (!_isFiniteSnapshot(snapshot)) return null;

    _buffer.add(
      _BufferedSnapshot(
        snapshot: snapshot,
        capturedAt: capturedAt ?? DateTime.now().toUtc(),
      ),
    );

    if (_buffer.length < WindowContract.samplesPerSignal) return null;

    final windowItems = _buffer
        .take(WindowContract.samplesPerSignal)
        .toList(growable: false);
    final windowStart = windowItems.first.capturedAt;
    final window = TelemetryWindow(
      windowStart: windowStart,
      windowEnd: windowStart.add(
        const Duration(milliseconds: WindowContract.durationMs),
      ),
      sampleRateHz: WindowContract.sampleRateHz,
      samples: _samplesFrom(windowItems),
      context: _contextFrom(windowItems.last.snapshot),
    );

    final hopSamples = _nextHopSamples();
    _buffer.removeRange(0, hopSamples.clamp(0, _buffer.length));
    return window;
  }

  void reset() {
    _buffer.clear();
    _hopCarry = 0;
  }

  Map<String, List<double>> _samplesFrom(List<_BufferedSnapshot> items) {
    return {
      'accX': [for (final item in items) item.snapshot.accelX],
      'accY': [for (final item in items) item.snapshot.accelY],
      'accZ': [for (final item in items) item.snapshot.accelZ],
      'gyroX': [for (final item in items) item.snapshot.gyroX],
      'gyroY': [for (final item in items) item.snapshot.gyroY],
      'gyroZ': [for (final item in items) item.snapshot.gyroZ],
    };
  }

  Map<String, double>? _contextFrom(SensorSnapshot snapshot) {
    final context = <String, double>{};
    final optionalValues = {
      'heartRate': snapshot.heartRate,
      'roomTemp': snapshot.roomTemp,
      'roomLight': snapshot.roomLight,
    };

    for (final entry in optionalValues.entries) {
      if (entry.value.isFinite && entry.value != 0.0) {
        context[entry.key] = entry.value;
      }
    }

    return context.isEmpty ? null : context;
  }

  int _nextHopSamples() {
    final exactHop =
        WindowContract.samplesPerSignal * (1 - WindowContract.overlapRatio);
    final baseHop = exactHop.floor();
    _hopCarry += exactHop - baseHop;

    if (_hopCarry >= 1) {
      _hopCarry -= 1;
      return baseHop + 1;
    }

    return baseHop;
  }

  bool _isFiniteSnapshot(SensorSnapshot snapshot) {
    return snapshot.accelX.isFinite &&
        snapshot.accelY.isFinite &&
        snapshot.accelZ.isFinite &&
        snapshot.gyroX.isFinite &&
        snapshot.gyroY.isFinite &&
        snapshot.gyroZ.isFinite;
  }
}

class _BufferedSnapshot {
  const _BufferedSnapshot({required this.snapshot, required this.capturedAt});

  final SensorSnapshot snapshot;
  final DateTime capturedAt;
}
