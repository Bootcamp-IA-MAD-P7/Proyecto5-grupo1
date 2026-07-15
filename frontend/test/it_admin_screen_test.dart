import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/screens/it_admin_screen.dart';
import 'package:sentilife/services/admin_service.dart';
import 'package:sentilife/services/auth_session.dart';
import 'package:sentilife/services/secure_token_storage.dart';
import 'package:sentilife/services/session_repository.dart';

SessionRepository _adminSession() {
  SessionRepository.resetForTests();
  final session = SessionRepository(storage: InMemorySecureTokenStorage());
  SessionRepository.useForTests(session);
  session.setSession(
    const AuthTokens(
      accessToken: 'admin-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
      user: User(
        id: 'admin-1',
        email: 'admin@test.com',
        fullName: 'IT Admin',
        role: UserRole.itAdmin,
      ),
    ),
  );
  return session;
}

void main() {
  tearDown(() {
    SessionRepository.resetForTests();
  });

  testWidgets('export tab descarga CSV sin mostrar URL (T5.2)', (tester) async {
    var exportCalls = 0;
    final admin = AdminService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/export')) {
          exportCalls++;
          expect(req.headers['Authorization'], 'Bearer admin-token');
          return http.Response(
            'window_id,label\n',
            200,
            headers: {
              'content-type': 'text/csv',
              'content-disposition':
                  'attachment; filename="sentilife-feedback-all-all.csv"',
            },
          );
        }
        if (req.url.path.endsWith('/history')) {
          return http.Response(
            jsonEncode({
              'content': [],
              'number': 0,
              'size': 20,
              'totalElements': 0,
              'totalPages': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/users')) {
          return http.Response(
            jsonEncode({
              'content': [],
              'number': 0,
              'size': 20,
              'totalElements': 0,
              'totalPages': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/retrain/status')) {
          return http.Response(
            jsonEncode({'phase': 'IDLE'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        throw UnsupportedError('Unexpected: ${req.url}');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ItAdminScreen(
          session: _adminSession(),
          onLocaleChanged: (_) {},
          adminService: admin,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('http'), findsNothing);
    expect(find.textContaining('Export listo'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Exportar dataset'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(exportCalls, 1);
    expect(find.text('Dataset descargado correctamente.'), findsOneWidget);
  });
}
