import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/screens/caregiver_home_screen.dart';
import 'package:sentilife/services/auth_session.dart';
import 'package:sentilife/services/monitored_service.dart';
import 'package:sentilife/services/secure_token_storage.dart';

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _paged(List<Object> content) => {
      'content': content,
      'number': 0,
      'size': 20,
      'totalElements': content.length,
      'totalPages': 1,
    };

Map<String, dynamic> _personJson({String id = 'uuid-person-001'}) => {
      'id': id,
      'userId': 'uuid-monitored-user',
      'userEmail': 'monitored@test.com',
      'fullName': 'Manuel Pérez',
      'birthDate': '1948-03-12',
      'age': 78,
      'sex': 'M',
      'weightKg': 78.5,
      'heightCm': 172,
      'consentStatus': 'PENDING',
      'monitoringStatus': 'INACTIVE',
      'pairingCode': 'SL-84F2K9',
      'createdAt': '2026-07-08T10:00:00Z',
    };

Map<String, dynamic> _linkableAccount({
  required String email,
  String fullName = 'Manuel Pérez',
  bool active = true,
  bool alreadyLinked = false,
}) =>
    {
      'email': email,
      'fullName': fullName,
      'active': active,
      'alreadyLinked': alreadyLinked,
    };

SessionRepository _caregiverSession() {
  SessionRepository.resetForTests();
  final session = SessionRepository(storage: InMemorySecureTokenStorage());
  SessionRepository.useForTests(session);
  session.setSession(
    const AuthTokens(
      accessToken: 'test-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
      user: User(
        id: 'caregiver-1',
        email: 'caregiver@test.com',
        fullName: 'Ana García',
        role: UserRole.caregiver,
      ),
    ),
  );
  return session;
}

Widget _buildCaregiver({
  required MonitoredService monitoredService,
  AuthSession? session,
}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CaregiverHomeScreen(
      session: session ?? _caregiverSession(),
      onLocaleChanged: (_) {},
      monitoredService: monitoredService,
    ),
  );
}

Future<void> _openAddPersonDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    _buildCaregiver(
      monitoredService: MonitoredService(
        client: MockClient((_) async => _json(_paged([]))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.person_add));
  await tester.pumpAndSettle();
}

Future<void> _lookupEmail(WidgetTester tester, String monitoredEmail) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Email de la cuenta monitorizada'),
    monitoredEmail,
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> _pickDefaultBirthDate(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.calendar_today));
  await tester.pumpAndSettle();
  final okButtons = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byType(TextButton),
  );
  expect(okButtons, findsWidgets);
  await tester.tap(okButtons.last);
  await tester.pumpAndSettle();
}

Future<void> _fillPersonForm(
  WidgetTester tester, {
  required String monitoredEmail,
}) async {
  await _lookupEmail(tester, monitoredEmail);
  await _pickDefaultBirthDate(tester);
}

void main() {
  tearDown(() {
    SessionRepository.resetForTests();
  });

  testWidgets('formulario exige email de cuenta MONITORED', (tester) async {
    await _openAddPersonDialog(tester);

    expect(
      find.widgetWithText(TextField, 'Email de la cuenta monitorizada'),
      findsOneWidget,
    );
    expect(find.text('Nombre (desde la cuenta)'), findsOneWidget);
    expect(find.text('Contacto de emergencia'), findsOneWidget);
  });

  testWidgets('create envía monitoredUserEmail al backend', (tester) async {
    Map<String, dynamic>? sentBody;
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/linkable-account')) {
          return _json(_linkableAccount(email: 'monitored@test.com'));
        }
        if (req.method == 'GET') {
          return _json(_paged([]));
        }
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(_personJson(), 201);
      }),
    );

    await tester.pumpWidget(_buildCaregiver(monitoredService: monitoredService));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.person_add));
    await tester.pumpAndSettle();
    await _fillPersonForm(tester, monitoredEmail: 'monitored@test.com');
    expect(find.text('Manuel Pérez'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(sentBody?['monitoredUserEmail'], 'monitored@test.com');
    expect(sentBody?['fullName'], 'Manuel Pérez');
    expect(sentBody?['birthDate'], isNotNull);
  });

  testWidgets('muestra error 404 cuando el email no existe', (tester) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/linkable-account')) {
          return _json(
            {
              'error': 'NOT_FOUND',
              'message': 'Monitored user not found',
            },
            404,
          );
        }
        return _json(_paged([]));
      }),
    );

    await tester.pumpWidget(_buildCaregiver(monitoredService: monitoredService));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.person_add));
    await tester.pumpAndSettle();
    await _lookupEmail(tester, 'missing@test.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No se encontró una cuenta MONITORED activa con ese email',
      ),
      findsOneWidget,
    );
  });

  testWidgets('muestra error 400 cuando la cuenta no es MONITORED', (
    tester,
  ) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/linkable-account')) {
          return _json(
            {
              'error': 'BAD_REQUEST',
              'message': 'Linked account must have MONITORED role',
            },
            400,
          );
        }
        return _json(_paged([]));
      }),
    );

    await tester.pumpWidget(_buildCaregiver(monitoredService: monitoredService));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.person_add));
    await tester.pumpAndSettle();
    await _lookupEmail(tester, 'caregiver@test.com');

    expect(
      find.text('Linked account must have MONITORED role'),
      findsOneWidget,
    );
  });

  testWidgets('muestra error cuando la cuenta ya está vinculada', (
    tester,
  ) async {
    final monitoredService = MonitoredService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/linkable-account')) {
          return _json(
            _linkableAccount(
              email: 'linked@test.com',
              alreadyLinked: true,
            ),
          );
        }
        return _json(_paged([]));
      }),
    );

    await tester.pumpWidget(_buildCaregiver(monitoredService: monitoredService));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.person_add));
    await tester.pumpAndSettle();
    await _lookupEmail(tester, 'linked@test.com');

    expect(
      find.text('Esta cuenta ya está vinculada a otra ficha'),
      findsOneWidget,
    );
  });
}
