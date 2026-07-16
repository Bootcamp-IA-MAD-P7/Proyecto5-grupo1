import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';
import 'exceptions.dart';

class AssistantChatResponse {
  final String reply;
  final List<String> sources;
  final List<String> toolsUsed;
  final String? conversationId;
  final String? audioBase64;
  final String? contentType;

  const AssistantChatResponse({
    required this.reply,
    this.sources = const [],
    this.toolsUsed = const [],
    this.conversationId,
    this.audioBase64,
    this.contentType,
  });

  factory AssistantChatResponse.fromJson(Map<String, dynamic> json) {
    return AssistantChatResponse(
      reply: (json['reply'] as String?) ?? '',
      sources: (json['sources'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      toolsUsed:
          (json['toolsUsed'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      conversationId: json['conversationId'] as String?,
      audioBase64: json['audioBase64'] as String?,
      contentType: json['contentType'] as String?,
    );
  }
}

/// Cliente del asistente IA (proxy Java → agente Groq). RF-46 / RF-47.
class AssistantService {
  static const String _base = '${AppConfig.apiBaseUrl}/api/v1/assistant';

  final http.Client _client;

  AssistantService({http.Client? client}) : _client = client ?? http.Client();

  Future<AssistantChatResponse> chat({
    required String message,
    String? conversationId,
    String locale = 'es',
    bool tts = true,
  }) async {
    final headers = await apiJsonHeadersAsync();
    final resp = await _client.post(
      Uri.parse('$_base/chat'),
      headers: headers,
      body: jsonEncode({
        'message': message,
        'locale': locale,
        'tts': tts,
        'conversationId': ?conversationId,
      }),
    );
    if (resp.statusCode == 200) {
      return AssistantChatResponse.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    throw _parseError(resp);
  }

  Future<String> transcribe(List<int> audioBytes, {String filename = 'audio.m4a'}) async {
    final token = (await apiJsonHeadersAsync())['Authorization'];
    final req = http.MultipartRequest('POST', Uri.parse('$_base/transcribe'));
    if (token != null) {
      req.headers['Authorization'] = token;
    }
    req.files.add(
      http.MultipartFile.fromBytes('audio', audioBytes, filename: filename),
    );
    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['text'] as String?)?.trim() ?? '';
    }
    throw ApiException(
      streamed.statusCode,
      'ASSISTANT_ERROR',
      _messageFromBody(body, streamed.statusCode),
    );
  }

  ApiException _parseError(http.Response resp) {
    return ApiException(
      resp.statusCode,
      'ASSISTANT_ERROR',
      _messageFromBody(resp.body, resp.statusCode),
    );
  }

  String _messageFromBody(String body, int status) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['message'] as String?) ??
          (json['detail'] as String?) ??
          'Error del asistente ($status)';
    } catch (_) {
      return 'Error del asistente ($status)';
    }
  }
}
