class TelemetryWindow {
  TelemetryWindow({
    required this.windowStart,
    required this.windowEnd,
    required this.sampleRateHz,
    required Map<String, List<double>> samples,
    Map<String, double>? context,
  }) : samples = Map.unmodifiable(
         samples.map(
           (key, value) => MapEntry(key, List<double>.unmodifiable(value)),
         ),
       ),
       context = context == null ? null : Map.unmodifiable(context);

  final DateTime windowStart;
  final DateTime windowEnd;
  final int sampleRateHz;
  final Map<String, List<double>> samples;
  final Map<String, double>? context;
}
