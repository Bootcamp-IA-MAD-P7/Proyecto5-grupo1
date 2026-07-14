import '../models/user.dart';
import 'session_repository.dart';

/// Thin facade — delegates to [SessionRepository] (single source of truth).
class SessionManager {
  static final SessionManager _instance = SessionManager._();
  factory SessionManager() => _instance;
  SessionManager._();

  SessionRepository get _repo => SessionRepository.instance;

  bool get isLoggedIn => _repo.isLoggedIn;
  User? get currentUser => _repo.user;
  String? get accessToken => _repo.accessToken;
  String? get refreshToken => _repo.refreshToken;

  Future<void> login(AuthTokens tokens) => _repo.login(tokens);

  Future<void> logout() => _repo.logout();
}
