import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/services/device_id_service.dart';
import 'package:sentilife/services/devices_service.dart';
import 'package:sentilife/services/exceptions.dart';
import 'package:sentilife/services/monitored_context_store.dart';

void main() {
  group('DeviceIdService', () {
    tearDown(DeviceIdService.resetForTests);

    test('testOverride returns stable id', () async {
      DeviceIdService.testOverride = 'android-test-stable-001';
      final service = DeviceIdService();

      expect(await service.getStableDeviceId(), 'android-test-stable-001');
      expect(await service.getStableDeviceId(), 'android-test-stable-001');
    });
  });

  group('Monitored pairing flow (mock DevicesService)', () {
    tearDown(() => MonitoredContextStore().clear());

    test('pair stores monitoredPersonId and deviceId in context store', () async {
      final devices = DevicesService(useMock: true);
      final store = MonitoredContextStore();
      const deviceId = 'android-test-pair-001';

      final result = await devices.pair(
        pairingCode: 'SL-84F2K9',
        deviceId: deviceId,
      );

      store.setPairing(
        personId: result.monitoredPersonId,
        deviceId: deviceId,
      );

      expect(store.isPaired, isTrue);
      expect(store.monitoredPersonId, 'uuid-person-001');
      expect(store.deviceId, deviceId);
      expect(store.consentActive, isFalse);
    });

    test('invalid pairing code does not update store', () async {
      final devices = DevicesService(useMock: true);
      final store = MonitoredContextStore();

      await expectLater(
        devices.pair(pairingCode: 'SL-INVALID', deviceId: 'android-test'),
        throwsA(isA<DeviceException>().having((e) => e.status, 'status', 404)),
      );

      expect(store.isPaired, isFalse);
    });

    test('paired state skips re-pairing requirement', () {
      final store = MonitoredContextStore()
        ..setPairing(personId: 'person-1', deviceId: 'device-1');

      expect(store.isPaired, isTrue);
      expect(store.monitoredPersonId, 'person-1');
      expect(store.deviceId, 'device-1');
    });
  });
}
