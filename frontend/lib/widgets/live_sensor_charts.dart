import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/prediction_result.dart';

/// Rolling buffer of IMU samples for live charts (RF-41 / T5.4).
class RollingSensorBuffer {
  RollingSensorBuffer({this.windowSeconds = 30});

  final int windowSeconds;
  final List<_TimedSample> _samples = [];

  void add(SensorSnapshot snapshot) {
    final now = DateTime.now();
    _samples.add(_TimedSample(now, snapshot));
    final cutoff = now.subtract(Duration(seconds: windowSeconds));
    while (_samples.isNotEmpty && _samples.first.timestamp.isBefore(cutoff)) {
      _samples.removeAt(0);
    }
  }

  void clear() => _samples.clear();

  bool get isEmpty => _samples.isEmpty;

  List<FlSpot> spotsFor(double Function(SensorSnapshot) selector) {
    if (_samples.isEmpty) return const [];
    final origin = _samples.first.timestamp;
    return _samples
        .map((entry) {
          final x = entry.timestamp.difference(origin).inMilliseconds / 1000.0;
          return FlSpot(x, selector(entry.snapshot));
        })
        .toList(growable: false);
  }
}

class _TimedSample {
  const _TimedSample(this.timestamp, this.snapshot);

  final DateTime timestamp;
  final SensorSnapshot snapshot;
}

/// Live accelerometer/gyroscope charts from local sensor stream (RF-41).
class LiveSensorCharts extends StatefulWidget {
  const LiveSensorCharts({
    super.key,
    required this.sensorStream,
    required this.isMonitoring,
  });

  final Stream<SensorSnapshot> sensorStream;
  final bool isMonitoring;

  @override
  State<LiveSensorCharts> createState() => _LiveSensorChartsState();
}

class _LiveSensorChartsState extends State<LiveSensorCharts> {
  final RollingSensorBuffer _buffer = RollingSensorBuffer();
  StreamSubscription<SensorSnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _bindStream();
  }

  @override
  void didUpdateWidget(covariant LiveSensorCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorStream != widget.sensorStream ||
        oldWidget.isMonitoring != widget.isMonitoring) {
      _bindStream();
    }
    if (!widget.isMonitoring) {
      _buffer.clear();
    }
  }

  void _bindStream() {
    unawaited(_subscription?.cancel());
    _subscription = widget.sensorStream.listen((snapshot) {
      if (!widget.isMonitoring || !mounted) return;
      setState(() => _buffer.add(snapshot));
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!widget.isMonitoring) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.sensorsPausedMessage,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.liveSensorsCaption,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _SignalChartCard(
          title: l10n.accelerometer,
          unit: 'm/s²',
          series: [
            _ChartSeries(label: 'X', color: Colors.red, spots: _buffer.spotsFor((s) => s.accelX)),
            _ChartSeries(label: 'Y', color: Colors.green, spots: _buffer.spotsFor((s) => s.accelY)),
            _ChartSeries(label: 'Z', color: Colors.blue, spots: _buffer.spotsFor((s) => s.accelZ)),
          ],
        ),
        const SizedBox(height: 16),
        _SignalChartCard(
          title: l10n.gyroscope,
          unit: '°/s',
          series: [
            _ChartSeries(label: 'X', color: Colors.orange, spots: _buffer.spotsFor((s) => s.gyroX)),
            _ChartSeries(label: 'Y', color: Colors.purple, spots: _buffer.spotsFor((s) => s.gyroY)),
            _ChartSeries(label: 'Z', color: Colors.teal, spots: _buffer.spotsFor((s) => s.gyroZ)),
          ],
        ),
      ],
    );
  }
}

class _ChartSeries {
  const _ChartSeries({
    required this.label,
    required this.color,
    required this.spots,
  });

  final String label;
  final Color color;
  final List<FlSpot> spots;
}

class _SignalChartCard extends StatelessWidget {
  const _SignalChartCard({
    required this.title,
    required this.unit,
    required this.series,
  });

  final String title;
  final String unit;
  final List<_ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    final hasData = series.any((item) => item.spots.length >= 2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title ($unit)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                for (final item in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(item.label),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: hasData
                  ? LineChart(
                      LineChartData(
                        minX: series.first.spots.first.x,
                        maxX: series.first.spots.last.x,
                        lineBarsData: [
                          for (final item in series)
                            LineChartBarData(
                              spots: item.spots,
                              isCurved: false,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              color: item.color,
                            ),
                        ],
                        titlesData: const FlTitlesData(show: false),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: true),
                      ),
                    )
                  : Center(
                      child: Text(
                        context.l10n.startMonitoringHint,
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
