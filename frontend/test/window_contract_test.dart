import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/config/window_contract.dart';

void main() {
  test('SL-14 contract values are fixed for Flutter windows', () {
    expect(WindowContract.durationMs, 2500);
    expect(WindowContract.sampleRateHz, 50);
    expect(WindowContract.overlapRatio, 0.5);
    expect(WindowContract.hopMs, 1250);
    expect(WindowContract.samplesPerSignal, 125);
  });

  test('SL-14 contract sample keys match telemetry payload', () {
    expect(WindowContract.requiredSampleKeys, [
      'accX',
      'accY',
      'accZ',
      'gyroX',
      'gyroY',
      'gyroZ',
    ]);
    expect(WindowContract.optionalContextKeys, [
      'heartRate',
      'roomTemp',
      'roomLight',
    ]);
  });
}
