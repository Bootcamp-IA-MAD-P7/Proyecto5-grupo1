import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('MonitoredService acceptConsent (HTTP real)', () {
    test('acceptConsent (POST /consent) completes without error', () async {
      final service = MonitoredService(
        client: MockClient((req) async {
          expect(req.method, 'POST');
          expect(req.url.path, endsWith('/consent'));
          return http.Response('', 200);
        }),
      );

      await expectLater(
        service.acceptConsent('uuid-person-001', policyVersion: '1.0-es'),
        completes,
      );
    });
  });
}
