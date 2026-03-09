import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor that redacts Authorization headers from debug logs.
///
/// Prevents API keys from appearing in debug output even when
/// LogInterceptor is enabled.
class _RedactingLogInterceptor extends LogInterceptor {
  _RedactingLogInterceptor()
      : super(requestBody: true, responseBody: true);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final redacted = options.copyWith(
      headers: Map.of(options.headers)
        ..updateAll((k, v) =>
            (k.toLowerCase() == 'authorization' ||
                    k.toLowerCase() == 'x-api-key')
                ? '[REDACTED]'
                : v),
    );
    super.onRequest(redacted, handler);
  }
}

/// Creates a configured Dio instance for HTTP requests.
///
/// Default 5s receive timeout is fine for most requests (token claims,
/// balance-only fetches). Use [createSimplefinDioClient] for transaction
/// pulls that may take longer.
///
/// No retry interceptor — retries are dangerous with 24 req/day limit.
Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  return dio;
}

/// Creates a Dio instance for LLM API calls.
///
/// 30s receive timeout for streaming completions. Uses a redacting log
/// interceptor so API keys are never written to debug output.
Dio createLlmDioClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.stream,
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(_RedactingLogInterceptor());
  }

  return dio;
}

/// Creates a Dio instance for SimpleFIN transaction syncs.
///
/// Longer 60s receive timeout for initial 90-day transaction pulls
/// which can return large payloads from slow bank aggregators.
Dio createSimplefinDioClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  return dio;
}
