import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/services/device_id_service.dart';
import 'package:sentilife/services/devices_service.dart';
import 'package:sentilife/services/push_registration_service.dart';
import 'package:sentilife/services/session_manager.dart';

/// DevicesService que responde 200 a POST /push-token (backend real simulado).
DevicesService _devices() => DevicesService(
      client: MockClient((req) async => http.Response('', 200)),
    );

void main() {
  group('PushRegistrationService', () {
    tearDown(() {
      SessionManager().logout();
      DeviceIdService.resetForTests();
      PushRegistrationService.resetForTests();
    });

    test('skips registration for MONITORED role', () async {
      SessionManager().login(_tokensFor(UserRole.monitored));
      PushRegistrationService.fcmTokenOverride = () async => 'fcm-should-not-send';

      await expectLater(
        PushRegistrationService(
          devicesService: _devices(),
        ).registerForCaregiver(locale: 'es'),
        completes,
      );
    });

    test('skips registration when FCM token is unavailable', () async {
      SessionManager().login(_tokensFor(UserRole.caregiver));
      PushRegistrationService.fcmTokenOverride = () async => null;

      await expectLater(
        PushRegistrationService(
          devicesService: _devices(),
        ).registerForCaregiver(locale: 'es'),
        completes,
      );
    });

    test('registers push token for CAREGIVER after login', () async {
      SessionManager().login(_tokensFor(UserRole.caregiver));
      DeviceIdService.testOverride = 'android-caregiver-push-001';
      PushRegistrationService.fcmTokenOverride = () async => 'fcm-test-token-abc';

      await expectLater(
        PushRegistrationService(
          devicesService: _devices(),
        ).registerForCaregiver(locale: 'en'),
        completes,
      );
    });
  });
}

AuthTokens _tokensFor(UserRole role) {
  return AuthTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresIn: 3600,
    user: User(
      id: 'user-${role.value}',
      email: '${role.value.toLowerCase()}@test.com',
      fullName: 'Test ${role.value}',
      role: role,
      locale: 'es',
    ),
  );
}
