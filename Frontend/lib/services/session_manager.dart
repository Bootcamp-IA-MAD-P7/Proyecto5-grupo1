import '../models/user.dart';

/// In-memory session manager.
/// Holds the current auth tokens and user info after login.
/// For production, use flutter_secure_storage.
class SessionManager {
  static final SessionManager _instance = SessionManager._();
  factory SessionManager() => _instance;
  SessionManager._();

  AuthTokens? _tokens;
  User? _currentUser;

  bool get isLoggedIn => _tokens != null && _currentUser != null;
  User? get currentUser => _currentUser;
  String? get accessToken => _tokens?.accessToken;
  String? get refreshToken => _tokens?.refreshToken;

  void login(AuthTokens tokens) {
    _tokens = tokens;
    _currentUser = tokens.user;
  }

  void logout() {
    _tokens = null;
    _currentUser = null;
  }
}
