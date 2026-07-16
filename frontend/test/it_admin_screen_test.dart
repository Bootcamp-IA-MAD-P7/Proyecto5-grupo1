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

  testWidgets('historial tiene sub-tabs y filtro de feedback', (tester) async {
    final urls = <Uri>[];
    final admin = AdminService(
      client: MockClient((req) async {
        urls.add(req.url);
        if (req.url.path.endsWith('/monitored-persons')) {
          return http.Response(
            jsonEncode([
              {'id': 'person-1', 'fullName': 'Manuel Pérez'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/history')) {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'alertId': 'a1',
                  'monitoredPersonId': 'person-1',
                  'monitoredPersonName': 'Manuel Pérez',
                  'detectedAt': '2026-07-13T10:00:00Z',
                  'confidence': 0.9,
                  'modelVersion': 'v1',
                  'alertStatus': 'CONFIRMED',
                  'feedbackLabel': 'TRUE_FALL',
                },
              ],
              'number': 0,
              'size': 20,
              'totalElements': 1,
              'totalPages': 1,
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
        if (req.url.path.endsWith('/retrain/prerequisites')) {
          return http.Response(
            jsonEncode({
              'feedbackRecords': 5,
              'minFeedbackRecords': 5,
              'recommendedFeedbackRecords': 10,
              'eligible': true,
              'message': 'ok',
            }),
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

    expect(find.text('Con feedback'), findsOneWidget);
    expect(find.text('Todas las personas'), findsWidgets);

    await tester.tap(find.text('Con feedback'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Aceptados'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Rechazados'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Aceptados'));
    await tester.pumpAndSettle();

    final feedbackCalls = urls.where((u) => u.path.endsWith('/history')).toList();
    expect(
      feedbackCalls.any((u) => u.queryParameters['requireFeedback'] == 'true'),
      isTrue,
    );
    expect(
      feedbackCalls.any((u) => u.queryParameters['feedbackLabel'] == 'TRUE_FALL'),
      isTrue,
    );
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
        if (req.url.path.endsWith('/history') ||
            req.url.path.endsWith('/users') ||
            req.url.path.endsWith('/monitored-persons')) {
          if (req.url.path.endsWith('/monitored-persons')) {
            return http.Response(
              jsonEncode([]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
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
        if (req.url.path.endsWith('/retrain/prerequisites')) {
          return http.Response(
            jsonEncode({
              'feedbackRecords': 2,
              'minFeedbackRecords': 5,
              'recommendedFeedbackRecords': 10,
              'eligible': false,
              'message': 'Insufficient feedback',
            }),
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

  testWidgets('MLOps deshabilita retrain con feedback insuficiente (T5.5)', (tester) async {
    final admin = AdminService(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/monitored-persons')) {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/history') ||
            req.url.path.endsWith('/users')) {
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
        if (req.url.path.endsWith('/retrain/prerequisites')) {
          return http.Response(
            jsonEncode({
              'feedbackRecords': 2,
              'minFeedbackRecords': 5,
              'recommendedFeedbackRecords': 10,
              'eligible': false,
              'message': 'Insufficient',
            }),
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

    await tester.tap(find.text('MLOps'));
    await tester.pumpAndSettle();

    expect(find.text('2 de 5 registros mínimos'), findsOneWidget);
    final startButton = find.widgetWithText(FilledButton, 'Iniciar reentrenamiento');
    final button = tester.widget<FilledButton>(startButton);
    expect(button.onPressed, isNull);

    await tester.tap(find.text('¿Por qué está deshabilitado?'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay suficiente feedback'), findsOneWidget);
  });
}
