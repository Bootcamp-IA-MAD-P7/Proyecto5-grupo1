import 'package:flutter/foundation.dart';

import '../models/user.dart';

/// Sesión JWT en memoria, poblada tras el login real contra el backend Java.
class AuthSession extends ChangeNotifier {
  AuthTokens? _tokens;

  bool get isLoggedIn => _tokens != null;
  User? get user => _tokens?.user;
  String? get accessToken => _tokens?.accessToken;
  String? get refreshToken => _tokens?.refreshToken;

  void setSession(AuthTokens tokens) {
    _tokens = tokens;
    notifyListeners();
  }

  void clear() {
    _tokens = null;
    notifyListeners();
  }
}
