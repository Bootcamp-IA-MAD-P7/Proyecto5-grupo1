import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user.dart';
import 'exceptions.dart';

/// Servicio de autenticación — spec §6.1 (backend Java real).
///
/// [client] es inyectable para tests (`MockClient` de `package:http/testing`).
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/auth';

  /// POST /register — rol admitido: CAREGIVER | MONITORED
  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String locale = 'es',
  }) async {
    final res = await _client.post(
      Uri.parse('$_base/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': role.value,
        'locale': locale,
      }),
    );
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  /// POST /login
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      Uri.parse('$_base/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(res);
    return AuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST /refresh
  Future<AuthTokens> refresh(String refreshToken) async {
    final res = await _client.post(
      Uri.parse('$_base/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    _checkStatus(res);
    return AuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw AuthException(
        res.statusCode,
        body?['error'] as String? ?? 'ERROR',
        body?['message'] as String? ?? 'Error del servidor.',
      );
    }
  }
}
