import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/services/monitored_context_store.dart';
import 'package:sentilife/services/monitored_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testUserId = 'user-monitored-consent';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MonitoredContextStore().resetInMemoryForTests();
  });

  group('MonitoredContextStore', () {
    tearDown(() async {
      final store = MonitoredContextStore()..bindUser(_testUserId);
      await store.clear();
    });

    test('pairing resets consent flag', () async {
      final store = MonitoredContextStore()..bindUser(_testUserId);
      await store.setConsentActive(true);
      await store.setPairing(
        personId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
      );

      expect(store.isPaired, isTrue);
      expect(store.consentActive, isFalse);
    });

    test('pairing recovery preserves consent flag', () async {
      final store = MonitoredContextStore()..bindUser(_testUserId);
      await store.setConsentActive(true);
      await store.setPairing(
        personId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
        resetConsent: false,
      );

      expect(store.isPaired, isTrue);
      expect(store.consentActive, isTrue);
    });

    test('cold start bindUser does not wipe persisted state before load', () async {
      final store = MonitoredContextStore()..bindUser(_testUserId);
      await store.setPairing(
        personId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
      );
      await store.setConsentActive(true);

      store.resetInMemoryForTests();
      store.bindUser(_testUserId);
      expect(store.isPaired, isFalse);
      expect(store.consentActive, isFalse);

      await store.load();
      expect(store.isPaired, isTrue);
      expect(store.consentActive, isTrue);
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
