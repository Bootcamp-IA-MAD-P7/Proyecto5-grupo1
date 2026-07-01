import 'dart:math';
import '../models/prediction_result.dart';

class ApiService {
  // Cuando tengas el backend real, cambia esto por tu URL:
  // static const String _baseUrl = 'http://localhost:8000';

  /// Llama al modelo de predicción.
  /// Por ahora devuelve datos mockeados con un pequeño delay para simular red.
  Future<PredictionResult> predict(Map<String, dynamic> features) async {
    // Simula latencia de red
    await Future.delayed(const Duration(milliseconds: 800));

    // --- MOCK LOGIC ---
    // Lógica sencilla basada en los inputs para que el mock sea coherente:
    // Si la puntuación media de servicios es >= 3.5 → satisfecho
    final scores = [
      features['inflight_wifi'] as int,
      features['food_and_drink'] as int,
      features['seat_comfort'] as int,
      features['inflight_entertainment'] as int,
      features['cleanliness'] as int,
      features['online_boarding'] as int,
    ];
    final avg = scores.reduce((a, b) => a + b) / scores.length;

    // Añade algo de aleatoriedad para que no sea determinista
    final noise = (Random().nextDouble() - 0.5) * 0.4;
    final satisfiedProb = ((avg - 1) / 4 + noise).clamp(0.05, 0.95);
    final dissatisfiedProb = 1.0 - satisfiedProb;

    final label = satisfiedProb >= 0.5 ? 'satisfied' : 'neutral or dissatisfied';

    return PredictionResult(
      label: label,
      confidence: satisfiedProb >= 0.5 ? satisfiedProb : dissatisfiedProb,
      probabilities: {
        'satisfied': satisfiedProb,
        'neutral or dissatisfied': dissatisfiedProb,
      },
    );

    // --- CÓDIGO REAL (descomentar cuando tengas el backend) ---
    // final response = await http.post(
    //   Uri.parse('$_baseUrl/predict'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode(features),
    // );
    // if (response.statusCode == 200) {
    //   return PredictionResult.fromJson(jsonDecode(response.body));
    // } else {
    //   throw Exception('Error del servidor: ${response.statusCode}');
    // }
  }
}
