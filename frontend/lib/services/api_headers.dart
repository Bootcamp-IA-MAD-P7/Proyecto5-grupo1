import 'session_repository.dart';

/// Cabeceras JSON para llamadas autenticadas al backend Java.
///
/// Prefer [apiJsonHeadersAsync] in services so expired access tokens are
/// refreshed automatically via the stored refresh token.
Map<String, String> apiJsonHeaders({
  bool requireAuth = true,
  String? accessToken,
}) {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (requireAuth) {
    final token = accessToken ?? SessionRepository.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
  }
  return headers;
}

/// Returns JSON headers with a valid access token, refreshing when needed.
Future<Map<String, String>> apiJsonHeadersAsync({bool requireAuth = true}) async {
  if (!requireAuth) {
    return apiJsonHeaders(requireAuth: false);
  }
  final token = await SessionRepository.instance.ensureValidAccessToken();
  return apiJsonHeaders(requireAuth: true, accessToken: token);
}
