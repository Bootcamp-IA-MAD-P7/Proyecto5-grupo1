import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/services/device_id_service.dart';
import 'package:sentilife/services/devices_service.dart';
import 'package:sentilife/services/monitored_context_store.dart';
import 'package:sentilife/services/exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DevicesService cuyo POST /pair resuelve un pairingCode conocido.
DevicesService _pairingDevices() => DevicesService(
  client: MockClient((req) async {
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    const codes = {
      'SL-84F2K9': 'uuid-person-001',
      'SL-77X3M1': 'uuid-person-002',
    };
    final personId = codes[body['pairingCode']];
    if (personId == null) {
      return http.Response(
        jsonEncode({'error': 'INVALID_CODE', 'message': 'Código inválido'}),
        404,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode({
        'monitoredPersonId': personId,
        'deviceToken': 'device-token-$personId',
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

const _testUserId = 'user-monitored-test';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MonitoredContextStore().resetInMemoryForTests();
  });

  group('DeviceIdService', () {
    tearDown(DeviceIdService.resetForTests);

    test('testOverride returns stable id', () async {
      DeviceIdService.testOverride = 'android-test-stable-001';
      final service = DeviceIdService();

      expect(await service.getStableDeviceId(), 'android-test-stable-001');
      expect(await service.getStableDeviceId(), 'android-test-stable-001');
    });
  });

  group('Monitored pairing flow (HTTP real)', () {
    tearDown(() async {
      final store = MonitoredContextStore()..bindUser(_testUserId);
      await store.clear();
    });

    test(
      'pair stores monitoredPersonId and deviceId in context store',
      () async {
        final devices = _pairingDevices();
        final store = MonitoredContextStore()..bindUser(_testUserId);
        const deviceId = 'android-test-pair-001';

        final result = await devices.pair(
          pairingCode: 'SL-84F2K9',
          deviceId: deviceId,
        );

        await store.setPairing(
          personId: result.monitoredPersonId,
          deviceId: deviceId,
          deviceToken: result.deviceToken,
        );

        expect(store.isPaired, isTrue);
        expect(store.monitoredPersonId, 'uuid-person-001');
        expect(store.deviceId, deviceId);
        expect(store.deviceToken, 'device-token-uuid-person-001');
        expect(store.consentActive, isFalse);
      },
    );

    test('invalid pairing code does not update store', () async {
      final devices = _pairingDevices();
      final store = MonitoredContextStore()..bindUser(_testUserId);

      await expectLater(
        devices.pair(pairingCode: 'SL-INVALID', deviceId: 'android-test'),
        throwsA(isA<DeviceException>().having((e) => e.status, 'status', 404)),
      );

      expect(store.isPaired, isFalse);
    });

    test('paired state skips re-pairing requirement', () async {
      final store = MonitoredContextStore()..bindUser(_testUserId);
      await store.setPairing(
        personId: 'person-1',
        deviceId: 'device-1',
        deviceToken: 'token-1',
      );

      expect(store.isPaired, isTrue);
      expect(store.monitoredPersonId, 'person-1');
      expect(store.deviceId, 'device-1');
      expect(store.deviceToken, 'token-1');
    });

    test(
      'pairing is restored from SharedPreferences after process restart',
      () async {
        final store = MonitoredContextStore()..bindUser(_testUserId);
        await store.setPairing(
          personId: 'person-persisted',
          deviceId: 'device-persisted',
          deviceToken: 'token-persisted',
        );

        store.resetInMemoryForTests();
        store.bindUser(_testUserId);
        await store.load();

        expect(store.isPaired, isTrue);
        expect(store.monitoredPersonId, 'person-persisted');
        expect(store.deviceId, 'device-persisted');
        expect(store.deviceToken, 'token-persisted');
      },
    );

    test(
      'legacy global preferences migrate into user namespace on load',
      () async {
        SharedPreferences.setMockInitialValues({
          'monitored_person_id': 'legacy-person',
          'monitored_device_id': 'legacy-device',
          'monitored_consent_active': true,
        });
        final store = MonitoredContextStore()
          ..resetInMemoryForTests()
          ..bindUser(_testUserId);

        await store.load();

        expect(store.monitoredPersonId, 'legacy-person');
        expect(store.deviceId, 'legacy-device');
        expect(store.deviceToken, isNull);
        expect(store.requiresRepairing, isTrue);
        expect(store.isPaired, isFalse);
      },
    );

    test('different userId does not read another account namespace', () async {
      final storeA = MonitoredContextStore()..bindUser('user-a');
      await storeA.setPairing(
        personId: 'person-a',
        deviceId: 'device-a',
        deviceToken: 'token-a',
      );

      final storeB = MonitoredContextStore()..bindUser('user-b');
      await storeB.load();

      expect(storeB.isPaired, isFalse);
    });
  });
}
