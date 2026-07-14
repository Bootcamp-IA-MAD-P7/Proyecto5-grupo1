import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/models/push_alert_payload.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/services/logout_service.dart';
import 'package:sentilife/services/monitored_context_store.dart';
import 'package:sentilife/services/push_notification_service.dart';
import 'package:sentilife/services/secure_token_storage.dart';
import 'package:sentilife/services/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T2c.10 — MONITORED → CAREGIVER on same device without cross-account leakage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const monitoredUser = User(
    id: 'user-monitored-a',
    email: 'monitored@test.com',
    fullName: 'Monitored A',
    role: UserRole.monitored,
  );

  const caregiverUser = User(
    id: 'user-caregiver-b',
    email: 'caregiver@test.com',
    fullName: 'Caregiver B',
    role: UserRole.caregiver,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MonitoredContextStore().resetInMemoryForTests();
    SessionRepository.resetForTests();
    SessionRepository.useForTests(
      SessionRepository(storage: InMemorySecureTokenStorage()),
    );
    PushNotificationService.resetForTests();
  });

  tearDown(SessionRepository.resetForTests);

  group('Account isolation MONITORED → CAREGIVER', () {
    test('context is namespaced per userId', () async {
      final store = MonitoredContextStore();

      store.bindUser(monitoredUser.id);
      await store.setPairing(
        personId: 'person-a',
        deviceId: 'device-shared',
        deviceToken: 'token-a',
      );

      store.bindUser(caregiverUser.id);
      await store.load();
      expect(store.isPaired, isFalse);

      store.bindUser(monitoredUser.id);
      await store.load();
      expect(store.isPaired, isTrue);
      expect(store.monitoredPersonId, 'person-a');
    });

    test('logout MONITORED clears only that user namespace', () async {
      final store = MonitoredContextStore();

      store.bindUser(monitoredUser.id);
      await store.setPairing(
        personId: 'person-a',
        deviceId: 'device-shared',
        deviceToken: 'token-a',
      );

      store.bindUser(caregiverUser.id);
      await store.setPairing(
        personId: 'person-b',
        deviceId: 'device-shared',
        deviceToken: 'token-b',
      );

      store.bindUser(monitoredUser.id);
      await LogoutService().performLogout(
        user: monitoredUser,
        clearSession: () async {},
      );

      store.bindUser(monitoredUser.id);
      await store.load();
      expect(store.isPaired, isFalse);

      store.bindUser(caregiverUser.id);
      await store.load();
      expect(store.isPaired, isTrue);
      expect(store.monitoredPersonId, 'person-b');
    });

    test('push for other recipientUserId is rejected', () {
      SessionRepository.instance.setSession(
        const AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresIn: 900,
          user: caregiverUser,
        ),
      );

      final payload = PushAlertPayload.fromData({
        'type': 'FALL_ALERT',
        'alertId': 'alert-1',
        'recipientUserId': 'other-caregiver-id',
      });

      expect(
        PushNotificationService.shouldAcceptPayload(payload),
        isFalse,
      );

      final validPayload = PushAlertPayload.fromData({
        'type': 'FALL_ALERT',
        'alertId': 'alert-2',
        'recipientUserId': caregiverUser.id,
      });

      expect(
        PushNotificationService.shouldAcceptPayload(validPayload),
        isTrue,
      );
    });
  });
}
