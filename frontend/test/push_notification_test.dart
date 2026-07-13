import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/models/push_alert_payload.dart';
import 'package:sentilife/services/alerts_service.dart';
import 'package:sentilife/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushAlertPayload', () {
    test('parses FALL_ALERT data from backend', () {
      final payload = PushAlertPayload.fromData({
        'type': 'FALL_ALERT',
        'alertId': 'uuid-alert-001',
        'monitoredPersonId': 'uuid-person-001',
        'personName': 'Manuel Pérez',
        'confidence': '0.92',
      });

      expect(payload.isFallAlert, isTrue);
      expect(payload.alertId, 'uuid-alert-001');
      expect(payload.monitoredPersonId, 'uuid-person-001');
      expect(payload.personName, 'Manuel Pérez');
      expect(payload.confidence, closeTo(0.92, 0.001));
    });

    test('ignores unknown types', () {
      final payload = PushAlertPayload.fromData({
        'type': 'MONITORING_STARTED',
        'alertId': 'uuid-alert-001',
      });

      expect(payload.isFallAlert, isFalse);
    });
  });

  group('PushNotificationService pending navigation', () {
    tearDown(PushNotificationService.resetForTests);

    test('stores pending alert id when navigator is unavailable', () async {
      final navigated =
          await PushNotificationService.navigateToAlert('uuid-alert-001');

      expect(navigated, isFalse);
      expect(PushNotificationService.pendingAlertId, 'uuid-alert-001');
    });
  });

  group('AlertsService getById (mock)', () {
    test('returns alert by id', () async {
      final service = AlertsService(useMock: true);
      final alert = await service.getById('uuid-alert-001');

      expect(alert, isNotNull);
      expect(alert!.id, 'uuid-alert-001');
      expect(alert.monitoredPersonName, 'Manuel Pérez');
    });

    test('returns null for unknown id', () async {
      final service = AlertsService(useMock: true);
      final alert = await service.getById('unknown-id');

      expect(alert, isNull);
    });
  });
}
