import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/services/monitored_context_store.dart';
import 'package:sentilife/services/monitored_service.dart';

void main() {
  group('MonitoredContextStore', () {
    tearDown(() => MonitoredContextStore().clear());

    test('pairing resets consent flag', () {
      final store = MonitoredContextStore()
        ..setConsentActive(true)
        ..setPairing(personId: 'person-1', deviceId: 'device-1');

      expect(store.isPaired, isTrue);
      expect(store.consentActive, isFalse);
    });
  });

  group('consentPolicyVersion', () {
    test('uses locale language code', () {
      expect(consentPolicyVersion('es'), '1.0-es');
      expect(consentPolicyVersion('en'), '1.0-en');
    });
  });

  group('MonitoredService acceptConsent (mock)', () {
    test('acceptConsent completes without error in mock mode', () async {
      final service = MonitoredService(useMock: true);
      await expectLater(
        service.acceptConsent(
          'uuid-person-001',
          policyVersion: '1.0-es',
        ),
        completes,
      );
    });
  });
}
