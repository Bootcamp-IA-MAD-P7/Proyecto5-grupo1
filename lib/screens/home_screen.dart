import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _isLoading = false;

  // Parámetros del formulario
  int _age = 30;
  String _customerType = 'Loyal Customer';
  String _travelType = 'Business travel';
  String _flightClass = 'Business';
  int _flightDistance = 1000;

  // Puntuaciones de servicio (1-5)
  int _inflightWifi = 3;
  int _foodAndDrink = 3;
  int _seatComfort = 3;
  int _inflightEntertainment = 3;
  int _cleanliness = 3;
  int _onlineBoarding = 3;

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.predict({
        'age': _age,
        'customer_type': _customerType,
        'travel_type': _travelType,
        'class': _flightClass,
        'flight_distance': _flightDistance,
        'inflight_wifi': _inflightWifi,
        'food_and_drink': _foodAndDrink,
        'seat_comfort': _seatComfort,
        'inflight_entertainment': _inflightEntertainment,
        'cleanliness': _cleanliness,
        'online_boarding': _onlineBoarding,
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✈️ Predicción de Satisfacción'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Información del pasajero'),
            _sliderField(
              label: 'Edad: $_age años',
              value: _age.toDouble(),
              min: 7,
              max: 85,
              onChanged: (v) => setState(() => _age = v.round()),
            ),
            _dropdownField(
              label: 'Tipo de cliente',
              value: _customerType,
              items: ['Loyal Customer', 'disloyal Customer'],
              onChanged: (v) => setState(() => _customerType = v!),
            ),
            _dropdownField(
              label: 'Tipo de viaje',
              value: _travelType,
              items: ['Business travel', 'Personal Travel'],
              onChanged: (v) => setState(() => _travelType = v!),
            ),
            _dropdownField(
              label: 'Clase',
              value: _flightClass,
              items: ['Business', 'Eco', 'Eco Plus'],
              onChanged: (v) => setState(() => _flightClass = v!),
            ),
            _sliderField(
              label: 'Distancia del vuelo: $_flightDistance km',
              value: _flightDistance.toDouble(),
              min: 50,
              max: 5000,
              divisions: 99,
              onChanged: (v) => setState(() => _flightDistance = v.round()),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Puntuación de servicios (1 = muy malo, 5 = excelente)'),
            _ratingField('WiFi a bordo', _inflightWifi,
                (v) => setState(() => _inflightWifi = v)),
            _ratingField('Comida y bebida', _foodAndDrink,
                (v) => setState(() => _foodAndDrink = v)),
            _ratingField('Comodidad del asiento', _seatComfort,
                (v) => setState(() => _seatComfort = v)),
            _ratingField('Entretenimiento', _inflightEntertainment,
                (v) => setState(() => _inflightEntertainment = v)),
            _ratingField('Limpieza', _cleanliness,
                (v) => setState(() => _cleanliness = v)),
            _ratingField('Embarque online', _onlineBoarding,
                (v) => setState(() => _onlineBoarding = v)),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _predict,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Predecir satisfacción',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _sliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        initialValue: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _ratingField(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          ...List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => onChanged(star),
              child: Icon(
                star <= value ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 28,
              ),
            );
          }),
        ],
      ),
    );
  }
}
