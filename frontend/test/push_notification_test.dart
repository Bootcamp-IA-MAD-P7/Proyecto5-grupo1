import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/models/push_alert_payload.dart';
import 'package:sentilife/services/alerts_service.dart';
import 'package:sentilife/services/push_notification_service.dart';

http.Response _pagedAlert(String id) => http.Response(
      jsonEncode({
        'content': [
          {
            'id': id,
            'monitoredPersonId': 'uuid-person-001',
            'monitoredPersonName': 'Manuel Pérez',
            'detectedAt': '2026-07-13T10:00:00Z',
            'confidence': 0.92,
            'modelVersion': 'baseline-v1',
            'status': 'PENDING',
          }
        ],
        'number': 0,
        'size': 100,
        'totalElements': 1,
        'totalPages': 1,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

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
        'recipientUserId': 'uuid-caregiver-001',
      });

      expect(payload.isFallAlert, isTrue);
      expect(payload.alertId, 'uuid-alert-001');
      expect(payload.monitoredPersonId, 'uuid-person-001');
      expect(payload.personName, 'Manuel Pérez');
      expect(payload.confidence, closeTo(0.92, 0.001));
      expect(payload.recipientUserId, 'uuid-caregiver-001');
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

  group('AlertsService getById (HTTP real)', () {
    test('returns alert by id', () async {
      final service = AlertsService(
        client: MockClient((req) async => _pagedAlert('uuid-alert-001')),
      );
      final alert = await service.getById('uuid-alert-001');

      expect(alert, isNotNull);
      expect(alert!.id, 'uuid-alert-001');
      expect(alert.monitoredPersonName, 'Manuel Pérez');
    });

    test('returns null for unknown id', () async {
      final service = AlertsService(
        client: MockClient((req) async => _pagedAlert('uuid-alert-001')),
      );
      final alert = await service.getById('unknown-id');

      expect(alert, isNull);
    });
  });
}
