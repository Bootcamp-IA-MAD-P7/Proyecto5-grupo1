import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_token_storage.dart';

/// Production storage — only the refresh token is persisted (never the password).
class FlutterSecureTokenStorage implements SecureTokenStorage {
  static const _key = 'sentilife_refresh_token';

  final FlutterSecureStorage _storage;

  FlutterSecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _key);

  @override
  Future<void> deleteRefreshToken() => _storage.delete(key: _key);
}
