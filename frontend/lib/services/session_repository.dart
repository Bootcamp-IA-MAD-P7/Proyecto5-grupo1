import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'auth_service.dart';
import 'flutter_secure_token_storage.dart';
import 'secure_token_storage.dart';

/// Single source of truth for auth session — ADR-12 / T2c.8.
///
/// Persists only the refresh token in secure storage. On cold start,
/// [restoreSession] exchanges it via POST /auth/refresh.
class SessionRepository extends ChangeNotifier {
  static SessionRepository? _testOverride;
  static SessionRepository? _instance;

  static SessionRepository get instance =>
      _testOverride ?? (_instance ??= SessionRepository());

  SessionRepository({
    AuthService? authService,
    SecureTokenStorage? storage,
  })  : _authService = authService ?? AuthService(),
        _storage = storage ?? FlutterSecureTokenStorage();

  final AuthService _authService;
  final SecureTokenStorage _storage;

  AuthTokens? _tokens;
  bool _restoring = false;
  DateTime? _accessTokenExpiresAt;
  Future<String?>? _refreshInFlight;

  bool get isLoggedIn => _tokens != null;
  bool get isRestoring => _restoring;
  User? get user => _tokens?.user;
  String? get accessToken => _tokens?.accessToken;
  String? get refreshToken => _tokens?.refreshToken;

  /// Returns a valid access token, refreshing with the stored refresh token
  /// only when the current access token is actually expired.
  Future<String?> ensureValidAccessToken() async {
    if (_tokens == null) return null;

    final access = _tokens!.accessToken;
    if (access.isEmpty) return null;

    final expiresAt = _accessTokenExpiresAt;
    if (expiresAt == null || DateTime.now().isBefore(expiresAt)) {
      return access;
    }

    _refreshInFlight ??= _refreshAccessToken();
    try {
      return await _refreshInFlight;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Cold-start bootstrap: restore session from persisted refresh token.
  Future<void> restoreSession() async {
    if (_restoring || isLoggedIn) return;

    _restoring = true;
    notifyListeners();

    try {
      final stored = await _storage.readRefreshToken();
      if (stored == null || stored.isEmpty) return;

      final tokens = await _authService.refresh(stored);
      await _applyTokens(tokens);
    } catch (_) {
      await _storage.deleteRefreshToken();
      _tokens = null;
      notifyListeners();
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(AuthTokens tokens) => _applyTokens(tokens);

  /// Synchronous session update (tests / UI without re-persisting).
  void setSession(AuthTokens tokens) {
    _tokens = tokens;
    _accessTokenExpiresAt = _expiryFrom(tokens);
    notifyListeners();
  }

  Future<void> logout() async {
    _tokens = null;
    _accessTokenExpiresAt = null;
    _refreshInFlight = null;
    await _storage.deleteRefreshToken();
    notifyListeners();
  }

  Future<void> _applyTokens(AuthTokens tokens) async {
    _tokens = tokens;
    _accessTokenExpiresAt = _expiryFrom(tokens);
    await _storage.writeRefreshToken(tokens.refreshToken);
    notifyListeners();
  }

  Future<String?> _refreshAccessToken() async {
    final refresh = _tokens?.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;

    try {
      final tokens = await _authService.refresh(refresh);
      await _applyTokens(tokens);
      return tokens.accessToken;
    } catch (_) {
      await logout();
      return null;
    }
  }

  DateTime _expiryFrom(AuthTokens tokens) {
    final bufferSeconds = tokens.expiresIn > 30 ? 30 : 0;
    return DateTime.now().add(
      Duration(seconds: tokens.expiresIn - bufferSeconds),
    );
  }

  /// Alias for [logout] — backward compatible with prior [AuthSession.clear].
  Future<void> clear() => logout();

  /// Test hook — inject a repository with in-memory storage.
  static void useForTests(SessionRepository repo) {
    _testOverride = repo;
  }

  static void resetForTests() {
    _testOverride = null;
    _instance = null;
  }
}
