/// Abstraction over secure refresh-token persistence (testable without platform plugins).
abstract class SecureTokenStorage {
  Future<void> writeRefreshToken(String token);
  Future<String?> readRefreshToken();
  Future<void> deleteRefreshToken();
}

/// In-memory implementation for widget/unit tests.
class InMemorySecureTokenStorage implements SecureTokenStorage {
  String? _token;

  @override
  Future<void> deleteRefreshToken() async {
    _token = null;
  }

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> writeRefreshToken(String token) async {
    _token = token;
  }

  void reset() => _token = null;
}
