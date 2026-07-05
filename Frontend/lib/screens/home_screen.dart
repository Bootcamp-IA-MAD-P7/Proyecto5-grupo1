import 'dart:async';
import 'package:flutter/material.dart';
import '../models/prediction_result.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  StreamSubscription<SensorSnapshot>? _streamSubscription;
  SensorSnapshot? _latest;
  bool _monitoring = false;
  bool _analyzing = false;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _toggleMonitoring() {
    if (_monitoring) {
      _streamSubscription?.cancel();
      setState(() {
        _monitoring = false;
        _latest = null;
      });
    } else {
      _streamSubscription = _apiService.sensorStream().listen((snapshot) {
        setState(() => _latest = snapshot);
      });
      setState(() => _monitoring = true);
    }
  }

  Future<void> _analyze({bool simulateFall = false}) async {
    setState(() => _analyzing = true);
    try {
      final result = await _apiService.analyze(simulateFall: simulateFall);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Detector Tester'),
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Estado del monitoreo
          _StatusCard(monitoring: _monitoring),
          const SizedBox(height: 16),

          // Sensores en tiempo real
          if (_latest != null) ...[
            _SectionTitle('Lecturas de sensores'),
            const SizedBox(height: 8),
            _SensorGrid(snapshot: _latest!),
            const SizedBox(height: 16),
          ] else if (_monitoring) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Inicia el monitoreo para ver\nlos datos de los sensores',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          _SectionTitle('Acciones'),
          const SizedBox(height: 8),

          // Botón monitoreo
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _toggleMonitoring,
              icon: Icon(_monitoring ? Icons.stop : Icons.sensors),
              label: Text(_monitoring ? 'Detener monitoreo' : 'Iniciar monitoreo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _monitoring ? Colors.red[700] : primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botón analizar lectura actual
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _analyzing ? null : () => _analyze(),
              icon: _analyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: const Text('Analizar lectura'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botón simular caída (para testing)
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _analyzing ? null : () => _analyze(simulateFall: true),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Simular caída'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange[800],
                side: BorderSide(color: Colors.orange[800]!),
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

class _StatusCard extends StatelessWidget {
  final bool monitoring;
  const _StatusCard({required this.monitoring});

  @override
  Widget build(BuildContext context) {
    final color = monitoring ? Colors.green : Colors.grey;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.circle, color: color, size: 14),
            const SizedBox(width: 10),
            Text(
              monitoring ? 'Monitorizando...' : 'Inactivo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(
              monitoring ? Icons.favorite : Icons.favorite_border,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  final SensorSnapshot snapshot;
  const _SensorGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _SensorTile(
          icon: Icons.speed,
          label: 'Acelerómetro',
          value:
              'X: ${snapshot.accelX.toStringAsFixed(1)}\nY: ${snapshot.accelY.toStringAsFixed(1)}\nZ: ${snapshot.accelZ.toStringAsFixed(1)}',
          unit: 'm/s²',
        ),
        _SensorTile(
          icon: Icons.rotate_right,
          label: 'Giroscopio',
          value:
              'X: ${snapshot.gyroX.toStringAsFixed(1)}\nY: ${snapshot.gyroY.toStringAsFixed(1)}\nZ: ${snapshot.gyroZ.toStringAsFixed(1)}',
          unit: '°/s',
        ),
        _SensorTile(
          icon: Icons.favorite,
          label: 'Frec. cardíaca',
          value: snapshot.heartRate.toStringAsFixed(0),
          unit: 'ppm',
          color: Colors.red,
        ),
        _SensorTile(
          icon: Icons.thermostat,
          label: 'Temperatura',
          value: snapshot.roomTemp.toStringAsFixed(1),
          unit: '°C',
          color: Colors.orange,
        ),
        _SensorTile(
          icon: Icons.light_mode,
          label: 'Luz',
          value: snapshot.roomLight.toStringAsFixed(0),
          unit: 'lux',
          color: Colors.amber[700],
        ),
      ],
    );
  }
}

class _SensorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color? color;

  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: tileColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: tileColor,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
