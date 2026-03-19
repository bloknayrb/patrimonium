import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/error/app_error.dart';
import 'llm_client.dart';

/// LLM client for Google Gemini via the REST API (Dio-based).
class GeminiClient implements LlmClient {
  GeminiClient({
    required this.apiKey,
    required Dio dio,
    String model = 'gemini-2.5-flash',
  })  : _dio = dio,
        _model = model;

  final String apiKey;
  final Dio _dio;
  final String _model;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  @override
  String get providerName => 'gemini';

  @override
  String get modelName => _model;

  Map<String, dynamic> _buildBody(
      String systemPrompt, List<ChatMessage> messages) {
    final body = <String, dynamic>{
      'contents': messages.map((m) {
        final role = m.role == 'assistant' ? 'model' : 'user';
        return {
          'role': role,
          'parts': [
            {'text': m.content}
          ],
        };
      }).toList(),
    };
    if (systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt}
        ],
      };
    }
    return body;
  }

  @override
  Future<String> complete(
      String systemPrompt, List<ChatMessage> messages) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/$_model:generateContent?key=$apiKey',
        options: Options(
          headers: {'content-type': 'application/json'},
          responseType: ResponseType.json,
        ),
        data: _buildBody(systemPrompt, messages),
      );

      return _extractText(response.data!);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Stream<String> streamComplete(
      String systemPrompt, List<ChatMessage> messages) async* {
    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '$_baseUrl/$_model:streamGenerateContent?alt=sse&key=$apiKey',
        options: Options(
          headers: {
            'content-type': 'application/json',
            'accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
        data: _buildBody(systemPrompt, messages),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }

    final stream = response.data!.stream;
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk));
      final raw = buffer.toString();

      final lines = raw.split('\n');
      buffer
        ..clear()
        ..write(lines.last);

      for (final line in lines.sublist(0, lines.length - 1)) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data.isEmpty) continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final text = _extractTextOrNull(json);
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        } catch (_) {
          // Skip malformed SSE lines
        }
      }
    }
  }

  String _extractText(Map<String, dynamic> json) {
    final text = _extractTextOrNull(json);
    if (text == null || text.isEmpty) {
      throw const LLMError(message: 'Empty response from Gemini.');
    }
    return text;
  }

  String? _extractTextOrNull(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final content = (candidates.first as Map)['content'] as Map?;
    if (content == null) return null;
    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    return (parts.first as Map)['text'] as String?;
  }

  AppError _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    // Gemini returns 400 for invalid API keys
    if (statusCode == 400) {
      final error = data is Map ? data['error'] : null;
      final status = error is Map ? error['status'] : null;
      if (status == 'INVALID_ARGUMENT') {
        return LLMError.invalidApiKey('Gemini');
      }
    }
    if (statusCode == 429) return LLMError.rateLimited();
    if (statusCode == 500 || statusCode == 503) {
      return const LLMError(message: 'Gemini server error. Try again later.');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return LLMError.timeout();
    }
    return LLMError.apiError('Gemini');
  }
}
