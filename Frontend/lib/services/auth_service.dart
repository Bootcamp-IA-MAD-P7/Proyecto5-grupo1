import 'dart:convert';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user.dart';
import 'exceptions.dart';

/// Servicio de autenticación — spec §6.1
///
/// Con [_useMock] = true devuelve datos hardcodeados que implementan
/// exactamente los contratos de spec §6.1. Cuando el backend Java esté listo,
/// basta con poner [_useMock] = false.
class AuthService {
  static const bool _useMock = true;
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/auth';

  // ── Mock data ──────────────────────────────────────────────────────────────

  static final Map<String, Map<String, dynamic>> _mockUsers = {
    'caregiver@test.com': {
      'id': 'uuid-caregiver-001',
      'email': 'caregiver@test.com',
      'password': 'Test1234!',
      'fullName': 'Ana García',
      'role': 'CAREGIVER',
      'locale': 'es',
    },
    'monitored@test.com': {
      'id': 'uuid-monitored-001',
      'email': 'monitored@test.com',
      'password': 'Test1234!',
      'fullName': 'Manuel Pérez',
      'role': 'MONITORED',
      'locale': 'es',
    },
    'admin@test.com': {
      'id': 'uuid-admin-001',
      'email': 'admin@test.com',
      'password': 'Test1234!',
      'fullName': 'IT Admin',
      'role': 'IT_ADMIN',
      'locale': 'es',
    },
  };

  AuthTokens _mockTokens(Map<String, dynamic> u) {
    return AuthTokens(
      accessToken: 'mock-access-token-${u['id']}',
      refreshToken: 'mock-refresh-token-${u['id']}',
      expiresIn: 900,
      user: User.fromJson(u),
    );
  }

  // ── Interfaz pública ───────────────────────────────────────────────────────

  /// POST /register — rol admitido: CAREGIVER | MONITORED
  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String locale = 'es',
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (_mockUsers.containsKey(email)) {
        throw const AuthException(409, 'EMAIL_TAKEN', 'El email ya está registrado.');
      }
      final user = User(
        id: 'uuid-new-${email.hashCode.abs()}',
        email: email,
        fullName: fullName,
        role: role,
        locale: locale,
      );
      return user;
    }

    final res = await http.post(
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
    return User.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST /login
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      final u = _mockUsers[email];
      if (u == null || u['password'] != password) {
        throw const AuthException(401, 'INVALID_CREDENTIALS', 'Email o contraseña incorrectos.');
      }
      return _mockTokens(u);
    }

    final res = await http.post(
      Uri.parse('$_base/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _checkStatus(res);
    return AuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST /refresh
  Future<AuthTokens> refresh(String refreshToken) async {
    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      // Inferir usuario del token mock
      final userId = refreshToken.replaceFirst('mock-refresh-token-', '');
      final u = _mockUsers.values.firstWhere(
        (u) => u['id'] == userId,
        orElse: () => throw const AuthException(401, 'INVALID_TOKEN', 'Token de refresco inválido.'),
      );
      return _mockTokens(u);
    }

    final res = await http.post(
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
