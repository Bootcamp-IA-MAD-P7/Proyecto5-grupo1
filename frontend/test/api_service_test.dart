import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/models/prediction_result.dart';
import 'package:sentilife/services/api_service.dart';

void main() {
  test(
    'analyzeRemote sends the SL-7 window contract and reads camelCase',
    () async {
      late Map<String, dynamic> requestBody;
      final client = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'fallDetected': false,
            'confidence': 0.91,
            'modelVersion': 'threshold-baseline-0.1.0',
            'latencyMs': 0.5,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = ApiService(client: client);
      final snapshot = SensorSnapshot(
        accelX: 0.1,
        accelY: 0.2,
        accelZ: 9.8,
        gyroX: 0.3,
        gyroY: 0.4,
        gyroZ: 0.5,
        heartRate: 72,
        roomTemp: 22,
        roomLight: 300,
      );

      final result = await service.analyzeRemote(snapshot);

      expect(result.fallDetected, isFalse);
      expect(result.confidence, 0.91);
      expect(
        requestBody.keys,
        containsAll([
          'windowId',
          'monitoredId',
          'sampleRateHz',
          'samples',
          'subjectFeatures',
        ]),
      );
      final samples = requestBody['samples'] as Map<String, dynamic>;
      expect(samples['accX'], [0.1]);
      expect(samples['gyroZ'], [0.5]);
      expect(requestBody, isNot(contains('accel_x')));
    },
  );

  test(
    'simulate fall always sends values above the detection threshold',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final samples = body['samples'] as Map<String, dynamic>;
        expect((samples['accX'] as List).single, 20.0);
        expect((samples['gyroX'] as List).single, 400.0);
        return http.Response(
          jsonEncode({
            'fallDetected': true,
            'confidence': 0.99,
            'modelVersion': 'threshold-baseline-0.1.0',
            'latencyMs': 0.5,
          }),
          200,
        );
      });
      final service = ApiService(client: client);

      final result = await service.analyze(simulateFall: true);

      expect(result.fallDetected, isTrue);
    },
  );
}
