import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/screens/login_screen.dart';
import 'package:sentilife/services/auth_service.dart';
import 'package:sentilife/services/session_manager.dart';

Widget _buildLogin({AuthService? authService, VoidCallback? onLoginSuccess}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: LoginScreen(
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
  tearDown(() => SessionManager().logout());

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
      find.widgetWithText(TextFormField, 'Email'),
      'monitored@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'Password123!',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Registrarse'));
    await tester.pumpAndSettle();

    expect(registeredRole, 'MONITORED');
    expect(loginSucceeded, isTrue);
  });
}
