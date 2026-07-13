import 'session_manager.dart';

/// Cabeceras JSON para llamadas autenticadas al backend Java.
Map<String, String> apiJsonHeaders({bool requireAuth = true}) {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (requireAuth) {
    final token = SessionManager().accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
  }
  return headers;
}
