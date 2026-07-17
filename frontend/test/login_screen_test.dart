import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/screens/login_screen.dart';
import 'package:sentilife/services/auth_service.dart';
import 'package:sentilife/services/secure_token_storage.dart';
import 'package:sentilife/services/session_repository.dart';

Widget _buildLogin({
  AuthService? authService,
  VoidCallback? onLoginSuccess,
  Locale locale = const Locale('es'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: LoginScreen(
      session: SessionRepository.instance,
      authService: authService,
      onLoginSuccess: onLoginSuccess ?? () {},
    ),
  );
}

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  setUp(() {
    SessionRepository.resetForTests();
    SessionRepository.useForTests(
      SessionRepository(storage: InMemorySecureTokenStorage()),
    );
  });

  tearDown(() => SessionRepository.resetForTests());

  testWidgets(
    'registro permite elegir CAREGIVER o MONITORED pero no IT_ADMIN',
    (tester) async {
      await tester.pumpWidget(_buildLogin());
      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pump();

      expect(find.text('Cuidador'), findsOneWidget);
      expect(find.text('Persona monitorizada'), findsOneWidget);
      expect(find.text('Administrador IT'), findsNothing);
    },
  );

  testWidgets('registro envía MONITORED cuando se selecciona ese perfil', (
    tester,
  ) async {
    String? registeredRole;
    var loginSucceeded = false;
    final authService = AuthService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/register')) {
          registeredRole =
              (jsonDecode(request.body) as Map<String, dynamic>)['role']
                  as String;
          return _json({
            'user': {
              'id': 'monitored-1',
              'email': 'monitored@test.com',
              'fullName': 'Persona Monitorizada',
              'role': registeredRole,
              'locale': 'es',
            },
          }, 201);
        }

        return _json({
          'accessToken': 'access-token',
          'refreshToken': 'refresh-token',
          'expiresIn': 900,
          'user': {
            'id': 'monitored-1',
            'email': 'monitored@test.com',
            'fullName': 'Persona Monitorizada',
            'role': registeredRole,
            'locale': 'es',
          },
        });
      }),
    );

    await tester.pumpWidget(
      _buildLogin(
        authService: authService,
        onLoginSuccess: () => loginSucceeded = true,
      ),
    );
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pump();
    await tester.tap(find.text('Persona monitorizada'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Persona Monitorizada',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'monitored@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'Password123!',
    );
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Registrarse'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Registrarse'));
    await tester.pumpAndSettle();

    expect(registeredRole, 'MONITORED');
    expect(loginSucceeded, isTrue);
    expect(SessionRepository.instance.accessToken, 'access-token');
  });

  testWidgets('locale en muestra textos en inglés sin español residual', (
    tester,
  ) async {
    await tester.pumpWidget(_buildLogin(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Inicia sesión para continuar'), findsNothing);
    expect(find.text('Don\'t have an account? Register'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsNothing);

    await tester.tap(find.text('Don\'t have an account? Register'));
    await tester.pump();

    expect(find.text('Caregiver'), findsOneWidget);
    expect(find.text('Monitored person'), findsOneWidget);
    expect(find.text('Cuidador'), findsNothing);
    expect(find.text('Persona monitorizada'), findsNothing);
  });
}
