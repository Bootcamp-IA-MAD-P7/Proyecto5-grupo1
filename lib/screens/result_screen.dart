import 'package:flutter/material.dart';
import '../models/prediction_result.dart';

class ResultScreen extends StatelessWidget {
  final FallDetectionResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isFall = result.fallDetected;
    final color = isFall ? Colors.red[700]! : Colors.green[700]!;
    final icon = isFall ? Icons.warning_amber_rounded : Icons.check_circle_outline;
    final label = isFall ? '¡CAÍDA DETECTADA!' : 'Sin caída';
    final confidencePct = (result.confidence * 100).toStringAsFixed(1);
    final s = result.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        centerTitle: true,
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Icono y estado principal
          Center(
            child: Column(
              children: [
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
                const SizedBox(height: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confianza: $confidencePct%',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${result.timestamp.minute.toString().padLeft(2, '0')}:'
                  '${result.timestamp.second.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Alerta de emergencia (solo si hay caída)
          if (isFall) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.emergency, color: Colors.red[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerta de emergencia',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'En producción se notificaría al contacto de emergencia.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Datos del snapshot
          const Text(
            'LECTURA DEL SENSOR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          _DataRow('Acelerómetro',
              'X: ${s.accelX.toStringAsFixed(2)}  Y: ${s.accelY.toStringAsFixed(2)}  Z: ${s.accelZ.toStringAsFixed(2)} m/s²'),
          _DataRow('Giroscopio',
              'X: ${s.gyroX.toStringAsFixed(2)}  Y: ${s.gyroY.toStringAsFixed(2)}  Z: ${s.gyroZ.toStringAsFixed(2)} °/s'),
          _DataRow('Frec. cardíaca', '${s.heartRate.toStringAsFixed(0)} ppm'),
          _DataRow('Temperatura sala', '${s.roomTemp.toStringAsFixed(1)} °C'),
          _DataRow('Luz sala', '${s.roomLight.toStringAsFixed(0)} lux'),

          const SizedBox(height: 32),

          // Botón volver
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
