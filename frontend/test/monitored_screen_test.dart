import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/screens/monitored_screen.dart';
import 'package:sentilife/services/auth_session.dart';
import 'package:sentilife/services/monitored_context_store.dart';
import 'package:sentilife/services/monitored_service.dart';
import 'package:sentilife/services/secure_token_storage.dart';
import 'package:sentilife/services/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

SessionRepository _monitoredSession() {
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

Widget _buildMonitored({
  required MonitoredService monitoredService,
  MonitoredContextStore? contextStore,
}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MonitoredScreen(
      session: _monitoredSession(),
      onLocaleChanged: (_) {},
      monitoredService: monitoredService,
      contextStore: contextStore ?? MonitoredContextStore(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MonitoredContextStore().resetInMemoryForTests();
  });

  tearDown(() async {
    SessionRepository.resetForTests();
    final store = MonitoredContextStore()..bindUser('monitored-1');
    await store.clear();
  });

  testWidgets('cuenta MONITORED sin ficha muestra PENDING_LINK', (
    tester,
  ) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/me')) {
          return _json(
            {
              'error': 'NOT_FOUND',
              'message': 'Monitored profile not linked',
            },
            404,
          );
        }
        throw UnsupportedError('Unexpected request: ${req.url}');
      }),
    );

    await tester.pumpWidget(_buildMonitored(monitoredService: monitoredService));
    await tester.pumpAndSettle();

    expect(find.textContaining('PENDING_LINK'), findsOneWidget);
    expect(find.text('Vinculación pendiente'), findsOneWidget);
  });

  testWidgets('PENDING_LINK bloquea pairing y monitorización', (tester) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/me')) {
          return _json(
            {
              'error': 'NOT_FOUND',
              'message': 'Monitored profile not linked',
            },
            404,
          );
        }
        throw UnsupportedError('Unexpected request: ${req.url}');
      }),
    );

    await tester.pumpWidget(_buildMonitored(monitoredService: monitoredService));
    await tester.pumpAndSettle();

    expect(find.text('Código del cuidador'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Iniciar monitoreo'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Iniciar monitoreo'),
    );
    expect(startButton.onPressed, isNull);
  });
}
