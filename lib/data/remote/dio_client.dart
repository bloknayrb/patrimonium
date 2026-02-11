import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Creates a configured Dio instance for HTTP requests.
///
/// Conservative timeouts for SimpleFIN's rate-limited API.
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
