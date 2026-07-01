class PredictionResult {
  final String label;       // "satisfied" | "neutral or dissatisfied"
  final double confidence;  // 0.0 - 1.0
  final Map<String, double> probabilities;

  PredictionResult({
    required this.label,
    required this.confidence,
    required this.probabilities,
  });

  bool get isSatisfied => label == 'satisfied';

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: Map<String, double>.from(
        (json['probabilities'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
    );
  }
}
