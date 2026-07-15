import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/screens/sensor_unavailable_screen.dart';
import 'package:sentilife/services/auth_session.dart';
import 'package:sentilife/services/sensor_capability_service.dart';
import 'package:sentilife/services/secure_token_storage.dart';
import 'package:sentilife/services/session_repository.dart';

SessionRepository _session() {
  SessionRepository.resetForTests();
  final session = SessionRepository(storage: InMemorySecureTokenStorage());
  SessionRepository.useForTests(session);
  session.setSession(
    const AuthTokens(
      accessToken: 'test-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
      user: User(
        id: 'monitored-1',
        email: 'monitored@test.com',
        fullName: 'Manuel Pérez',
        role: UserRole.monitored,
      ),
    ),
  );
  return session;
}

void main() {
  testWidgets('shows blocking message when IMU sensors are missing', (
    tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SensorUnavailableScreen(
          session: _session(),
          onLocaleChanged: (_) {},
          result: const ImuCapabilityResult(
            accelerometerAvailable: false,
            gyroscopeAvailable: true,
          ),
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sensores no disponibles'), findsOneWidget);
    expect(find.text('Acelerómetro'), findsOneWidget);
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('Iniciar monitoreo'), findsNothing);

    await tester.tap(find.text('Comprobar de nuevo'));
    expect(retried, isTrue);
  });
}
