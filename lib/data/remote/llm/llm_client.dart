import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/error/app_error.dart';

/// A single message in an LLM conversation.
class LlmMessage {
  final String role;
  final String content;

  const LlmMessage({required this.role, required this.content});
}

/// Abstract LLM client. Each provider implements this.
abstract class LlmClient {
  /// Send messages and get a streaming response.
  /// Yields text chunks as they arrive from the LLM.
  Stream<String> sendMessageStream(List<LlmMessage> messages);

  /// Test the connection. Returns null on success, error message on failure.
  Future<String?> testConnection();
}

/// Factory to create the appropriate LLM client for a provider.
LlmClient createLlmClient(String provider, String apiKeyOrUrl, Dio dio) {
  switch (provider) {
    case 'claude':
      return ClaudeLlmClient(dio: dio, apiKey: apiKeyOrUrl);
    case 'openai':
      return OpenAiLlmClient(dio: dio, apiKey: apiKeyOrUrl);
    case 'ollama':
      return OllamaLlmClient(dio: dio, baseUrl: apiKeyOrUrl);
    default:
      throw LLMError.apiError(provider);
  }
}

// =============================================================================
// Claude (Anthropic Messages API)
// =============================================================================

class ClaudeLlmClient implements LlmClient {
  ClaudeLlmClient({
    required Dio dio,
    required String apiKey,
    this.model = 'claude-sonnet-4-20250514',
  })  : _dio = dio,
        _apiKey = apiKey;

  final Dio _dio;
  final String _apiKey;
  final String model;

  static const _baseUrl = 'https://api.anthropic.com/v1/messages';

  @override
  Stream<String> sendMessageStream(List<LlmMessage> messages) async* {
    // Separate system prompt from conversation messages
    final systemMessages = messages.where((m) => m.role == 'system').toList();
    final chatMessages = messages.where((m) => m.role != 'system').toList();

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': 4096,
      'stream': true,
      'messages': chatMessages.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList(),
    };
    if (systemMessages.isNotEmpty) {
      body['system'] = systemMessages.map((m) => m.content).join('\n\n');
    }

    final response = await _postStream(
      _baseUrl,
      body,
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
    );

    yield* _parseSseStream(response, (json) {
      if (json['type'] == 'content_block_delta') {
        final delta = json['delta'] as Map<String, dynamic>?;
        if (delta?['type'] == 'text_delta') {
          return delta!['text'] as String?;
        }
      }
      return null;
    });
  }

  @override
  Future<String?> testConnection() async {
    try {
      await _dio.post<Map<String, dynamic>>(
        _baseUrl,
        data: {
          'model': model,
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
        },
        options: Options(
          headers: {
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
        ),
      );
      return null;
    } on DioException catch (e) {
      return _mapDioError(e, 'claude');
    }
  }

  Future<ResponseBody> _postStream(
    String url,
    Map<String, dynamic> data, {
    required Map<String, String> headers,
  }) async {
    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: jsonEncode(data),
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapDioToLlmError(e, 'claude');
    }
  }
}

// =============================================================================
// OpenAI (Chat Completions API)
// =============================================================================

class OpenAiLlmClient implements LlmClient {
  OpenAiLlmClient({
    required Dio dio,
    required String apiKey,
    this.model = 'gpt-4o',
  })  : _dio = dio,
        _apiKey = apiKey;

  final Dio _dio;
  final String _apiKey;
  final String model;

  static const _baseUrl = 'https://api.openai.com/v1/chat/completions';

  @override
  Stream<String> sendMessageStream(List<LlmMessage> messages) async* {
    final body = {
      'model': model,
      'stream': true,
      'messages': messages.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList(),
    };

    final response = await _postStream(body);

    yield* _parseSseStream(response, (json) {
      final choices = json['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final delta = choices[0]['delta'] as Map<String, dynamic>?;
        return delta?['content'] as String?;
      }
      return null;
    });
  }

  @override
  Future<String?> testConnection() async {
    try {
      await _dio.post<Map<String, dynamic>>(
        _baseUrl,
        data: {
          'model': model,
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );
      return null;
    } on DioException catch (e) {
      return _mapDioError(e, 'openai');
    }
  }

  Future<ResponseBody> _postStream(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post<ResponseBody>(
        _baseUrl,
        data: jsonEncode(data),
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapDioToLlmError(e, 'openai');
    }
  }
}

// =============================================================================
// Ollama (Chat API)
// =============================================================================

class OllamaLlmClient implements LlmClient {
  OllamaLlmClient({
    required Dio dio,
    required String baseUrl,
    this.model = 'llama3.2',
  })  : _dio = dio,
        _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  final Dio _dio;
  final String _baseUrl;
  final String model;

  @override
  Stream<String> sendMessageStream(List<LlmMessage> messages) async* {
    ResponseBody response;
    try {
      final result = await _dio.post<ResponseBody>(
        '$_baseUrl/api/chat',
        data: jsonEncode({
          'model': model,
          'stream': true,
          'messages': messages.map((m) => {
            'role': m.role,
            'content': m.content,
          }).toList(),
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.stream,
        ),
      );
      response = result.data!;
    } on DioException catch (e) {
      throw _mapDioToLlmError(e, 'ollama');
    }

    // Ollama uses newline-delimited JSON (not SSE)
    var buffer = '';
    await for (final chunk in response.stream) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast(); // Keep incomplete line

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final message = json['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
          if (json['done'] == true) return;
        } catch (_) {
          // Skip malformed JSON lines
        }
      }
    }
  }

  @override
  Future<String?> testConnection() async {
    try {
      await _dio.get<dynamic>('$_baseUrl/api/tags');
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Cannot connect to Ollama at $_baseUrl. Is it running?';
      }
      return _mapDioError(e, 'ollama');
    }
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

/// Parse an SSE stream, extracting text using the provided [extractor].
Stream<String> _parseSseStream(
  ResponseBody response,
  String? Function(Map<String, dynamic> json) extractor,
) async* {
  var buffer = '';
  await for (final chunk in response.stream) {
    buffer += utf8.decode(chunk);
    final lines = buffer.split('\n');
    buffer = lines.removeLast(); // Keep incomplete line

    for (final line in lines) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final text = extractor(json);
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        } catch (_) {
          // Skip malformed JSON
        }
      }
    }
  }
}

/// Map a DioException to an LLMError.
LLMError _mapDioToLlmError(DioException e, String provider) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return LLMError.timeout();
  }

  final statusCode = e.response?.statusCode;
  if (statusCode == 401 || statusCode == 403) {
    return LLMError.invalidApiKey(provider);
  }
  if (statusCode == 429) {
    return LLMError.rateLimited();
  }

  if (e.type == DioExceptionType.connectionError) {
    if (provider == 'ollama') return LLMError.ollamaNotRunning();
    return LLMError.apiError(provider);
  }

  return LLMError.apiError(provider);
}

/// Map a DioException to a user-friendly error string for testConnection.
String _mapDioError(DioException e, String provider) {
  final statusCode = e.response?.statusCode;
  if (statusCode == 401 || statusCode == 403) {
    return 'Invalid API key';
  }
  if (statusCode == 429) {
    return 'Rate limited — try again in a moment';
  }
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    if (provider == 'ollama') return 'Cannot connect to Ollama. Is it running?';
    return 'Cannot connect to $provider API';
  }
  if (e.type == DioExceptionType.receiveTimeout) {
    return 'Request timed out';
  }
  return e.message ?? 'Connection failed';
}
