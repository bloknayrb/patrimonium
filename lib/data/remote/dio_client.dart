import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

/// Creates a Dio instance for LLM API calls (Claude, OpenAI, Ollama).
///
/// Longer 120s receive timeout for streaming LLM responses which can
/// take significant time for long outputs. responseBody logging disabled
/// since streaming responses are binary chunks.
Dio createLlmDioClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false,
    ));
  }

  return dio;
}
