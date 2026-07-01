import 'package:flutter/material.dart';
import '../models/prediction_result.dart';

class ResultScreen extends StatelessWidget {
  final PredictionResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.isSatisfied ? Colors.green : Colors.orange;
    final icon = result.isSatisfied ? Icons.sentiment_satisfied_alt : Icons.sentiment_dissatisfied;
    final label = result.isSatisfied ? 'SATISFECHO' : 'NO SATISFECHO';
    final confidencePct = (result.confidence * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono principal
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: Icon(icon, size: 64, color: color),
            ),
            const SizedBox(height: 24),

            // Etiqueta
            Text(
              label,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),

            // Confianza
            Text(
              'Confianza: $confidencePct%',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Barra de probabilidades
            _ProbabilityBar(
              label: 'Satisfecho',
              value: result.probabilities['satisfied'] ?? 0,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _ProbabilityBar(
              label: 'No satisfecho',
              value: result.probabilities['neutral or dissatisfied'] ?? 0,
              color: Colors.orange,
            ),
            const SizedBox(height: 40),

            // Botón volver
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text(
                  'Nueva predicción',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbabilityBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ProbabilityBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
