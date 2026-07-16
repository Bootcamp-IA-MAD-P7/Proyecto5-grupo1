import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentilife/models/user.dart';
import 'package:sentilife/services/auth_service.dart';
import 'package:sentilife/services/secure_token_storage.dart';
import 'package:sentilife/services/api_headers.dart';
import 'package:sentilife/services/session_repository.dart';

const _user = User(
  id: 'user-1',
  email: 'caregiver@test.com',
  fullName: 'Ana García',
  role: UserRole.caregiver,
);

const _tokens = AuthTokens(
  accessToken: 'access-new',
  refreshToken: 'refresh-new',
  expiresIn: 900,
  user: _user,
);

AuthService _refreshAuthService() => AuthService(
      client: MockClient((req) async {
        expect(req.url.path, endsWith('/refresh'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['refreshToken'], 'stored-refresh');
        return http.Response(
          jsonEncode({
            'accessToken': 'access-new',
            'refreshToken': 'refresh-rotated',
            'expiresIn': 900,
            'user': _user.toJson(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

void main() {
  late InMemorySecureTokenStorage storage;

  setUp(() {
    storage = InMemorySecureTokenStorage();
    SessionRepository.resetForTests();
    SessionRepository.useForTests(
      SessionRepository(authService: _refreshAuthService(), storage: storage),
    );
  });

  tearDown(() {
    storage.reset();
    SessionRepository.resetForTests();
  });

  test('restoreSession with valid refresh token logs user in', () async {
    await storage.writeRefreshToken('stored-refresh');
    final repo = SessionRepository.instance;

    await repo.restoreSession();

    expect(repo.isLoggedIn, isTrue);
    expect(repo.accessToken, 'access-new');
    expect(repo.user?.email, 'caregiver@test.com');
    expect(await storage.readRefreshToken(), 'refresh-rotated');
  });

  test('restoreSession with invalid refresh clears storage', () async {
    SessionRepository.useForTests(
      SessionRepository(
        authService: AuthService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'error': 'UNAUTHORIZED', 'message': 'expired'}),
              401,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
        storage: storage,
      ),
    );
    await storage.writeRefreshToken('expired-refresh');
    final repo = SessionRepository.instance;

    await repo.restoreSession();

    expect(repo.isLoggedIn, isFalse);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('login persists refresh token and logout clears it', () async {
    final repo = SessionRepository.instance;

    await repo.login(_tokens);

    expect(repo.isLoggedIn, isTrue);
    expect(await storage.readRefreshToken(), 'refresh-new');

    await repo.logout();

    expect(repo.isLoggedIn, isFalse);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('SessionManager and SessionRepository share the same session', () async {
    final repo = SessionRepository.instance;
    await repo.login(_tokens);

    expect(repo.accessToken, 'access-new');
    expect(repo.user?.id, 'user-1');
  });

  test('login persiste tokens en la misma sesión usada por los servicios HTTP', () async {
    final repo = SessionRepository.instance;
    await repo.login(_tokens);

    final headers = await apiJsonHeadersAsync();
    expect(headers['Authorization'], 'Bearer access-new');
    expect(repo.isLoggedIn, isTrue);
  });

  test('ensureValidAccessToken refreshes expired access token', () async {
    final repo = SessionRepository.instance;
    await repo.login(_tokens);
    repo.setSession(
      AuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'stored-refresh',
        expiresIn: 0,
        user: _user,
      ),
    );

    final token = await repo.ensureValidAccessToken();

    expect(token, 'access-new');
    expect(repo.accessToken, 'access-new');
    expect(await storage.readRefreshToken(), 'refresh-rotated');
  });
}
