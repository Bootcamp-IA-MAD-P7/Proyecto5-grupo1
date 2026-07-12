import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/config/window_contract.dart';
import 'package:sentilife/models/prediction_result.dart';
import 'package:sentilife/models/telemetry_window.dart';
import 'package:sentilife/services/sliding_window_builder.dart';

void main() {
  group('SlidingWindowBuilder', () {
    test('no emite antes de reunir 125 muestras', () {
      final builder = SlidingWindowBuilder();

      for (var i = 0; i < WindowContract.samplesPerSignal - 1; i++) {
        final window = builder.add(_snapshot(i), capturedAt: _time(i));
        expect(window, isNull);
      }
    });

    test('primera ventana contiene exactamente 125 muestras por señal', () {
      final window = _buildWindows(WindowContract.samplesPerSignal).single;

      expect(window.samples.keys, WindowContract.requiredSampleKeys);
      for (final values in window.samples.values) {
        expect(values, hasLength(WindowContract.samplesPerSignal));
      }
    });

    test('todas las señales tienen igual longitud', () {
      final window = _buildWindows(WindowContract.samplesPerSignal).single;
      final lengths = window.samples.values
          .map((values) => values.length)
          .toSet();

      expect(lengths, {WindowContract.samplesPerSignal});
    });

    test('windowEnd es windowStart + 2500 ms', () {
      final window = _buildWindows(WindowContract.samplesPerSignal).single;

      expect(
        window.windowEnd,
        window.windowStart.add(
          const Duration(milliseconds: WindowContract.durationMs),
        ),
      );
    });

    test('segunda ventana respeta el solape', () {
      final windows = _buildWindows(187);
      final firstAccX = windows[0].samples['accX']!;
      final secondAccX = windows[1].samples['accX']!;

      expect(windows, hasLength(2));
      expect(secondAccX.first, 62);
      expect(secondAccX.take(63), firstAccX.skip(62));
    });

    test('los hops alternan 62/63 y conservan promedio 62.5', () {
      final windows = _buildWindows(375);
      final starts = windows
          .map((window) => window.samples['accX']!.first.toInt())
          .toList();
      final hops = [
        for (var i = 1; i < starts.length; i++) starts[i] - starts[i - 1],
      ];
      final average = hops.reduce((a, b) => a + b) / hops.length;

      expect(starts, [0, 62, 125, 187, 250]);
      expect(hops, [62, 63, 62, 63]);
      expect(average, 62.5);
    });

    test('reset limpia el estado', () {
      final builder = SlidingWindowBuilder();

      for (var i = 0; i < WindowContract.samplesPerSignal - 1; i++) {
        expect(builder.add(_snapshot(i), capturedAt: _time(i)), isNull);
      }

      builder.reset();

      for (var i = 0; i < WindowContract.samplesPerSignal - 1; i++) {
        expect(builder.add(_snapshot(i), capturedAt: _time(i)), isNull);
      }

      final window = builder.add(
        _snapshot(WindowContract.samplesPerSignal - 1),
        capturedAt: _time(WindowContract.samplesPerSignal - 1),
      );
      expect(window, isNotNull);
    });

    test('NaN e infinito no generan ventanas inválidas', () {
      final builder = SlidingWindowBuilder();

      for (var i = 0; i < WindowContract.samplesPerSignal - 1; i++) {
        expect(builder.add(_snapshot(i), capturedAt: _time(i)), isNull);
      }

      expect(
        builder.add(_snapshot(double.nan), capturedAt: _time(999)),
        isNull,
      );
      expect(
        builder.add(_snapshot(double.infinity), capturedAt: _time(1000)),
        isNull,
      );

      final window = builder.add(
        _snapshot(WindowContract.samplesPerSignal - 1),
        capturedAt: _time(WindowContract.samplesPerSignal - 1),
      );

      expect(window, isNotNull);
      for (final values in window!.samples.values) {
        expect(values.every((value) => value.isFinite), isTrue);
      }
    });

    test('los arrays emitidos no pueden ser modificados externamente', () {
      final window = _buildWindows(WindowContract.samplesPerSignal).single;

      expect(() => window.samples['accX']!.add(999), throwsUnsupportedError);
      expect(() => window.samples['accX'] = [999], throwsUnsupportedError);
    });

    test('los placeholders 0.0 producen context null', () {
      final window = _buildWindows(WindowContract.samplesPerSignal).single;

      expect(window.context, isNull);
    });

    test('un contexto real y finito se conserva', () {
      final window = _buildWindows(
        WindowContract.samplesPerSignal,
        lastSnapshot: _snapshot(
          WindowContract.samplesPerSignal - 1,
          heartRate: 74,
          roomTemp: 22.5,
          roomLight: 310,
        ),
      ).single;

      expect(window.context, {
        'heartRate': 74.0,
        'roomTemp': 22.5,
        'roomLight': 310.0,
      });
    });

    test('un valor opcional NaN o infinito no invalida la ventana', () {
      final window = _buildWindows(
        WindowContract.samplesPerSignal,
        lastSnapshot: _snapshot(
          WindowContract.samplesPerSignal - 1,
          heartRate: double.nan,
          roomTemp: double.infinity,
          roomLight: 310,
        ),
      ).single;

      expect(window, isNotNull);
      expect(
        window.samples.values.every(
          (values) => values.every((value) => value.isFinite),
        ),
        isTrue,
      );
    });

    test('los valores opcionales inválidos no aparecen en context', () {
      final window = _buildWindows(
        WindowContract.samplesPerSignal,
        lastSnapshot: _snapshot(
          WindowContract.samplesPerSignal - 1,
          heartRate: double.nan,
          roomTemp: double.infinity,
          roomLight: 310,
        ),
      ).single;

      expect(window.context, {'roomLight': 310.0});
      expect(window.context, isNot(containsPair('heartRate', double.nan)));
      expect(window.context, isNot(containsPair('roomTemp', double.infinity)));
    });
  });
}

List<TelemetryWindow> _buildWindows(
  int sampleCount, {
  SensorSnapshot? lastSnapshot,
}) {
  final builder = SlidingWindowBuilder();
  final windows = <TelemetryWindow>[];

  for (var i = 0; i < sampleCount; i++) {
    final snapshot = i == sampleCount - 1 && lastSnapshot != null
        ? lastSnapshot
        : _snapshot(i);
    final window = builder.add(snapshot, capturedAt: _time(i));
    if (window != null) windows.add(window);
  }

  return windows;
}

SensorSnapshot _snapshot(
  num value, {
  double heartRate = 0,
  double roomTemp = 0,
  double roomLight = 0,
}) {
  final x = value.toDouble();
  return SensorSnapshot(
    accelX: x,
    accelY: x + 0.1,
    accelZ: x + 0.2,
    gyroX: x + 0.3,
    gyroY: x + 0.4,
    gyroZ: x + 0.5,
    heartRate: heartRate,
    roomTemp: roomTemp,
    roomLight: roomLight,
  );
}

DateTime _time(int index) {
  return DateTime.utc(2026, 7, 8).add(
    Duration(
      microseconds:
          Duration.microsecondsPerSecond ~/ WindowContract.sampleRateHz * index,
    ),
  );
}
