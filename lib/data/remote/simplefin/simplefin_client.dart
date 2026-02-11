import 'dart:convert';

import 'package:dio/dio.dart';

import 'simplefin_models.dart';

/// Client for the SimpleFIN Bridge protocol.
///
/// Handles token claiming and account/transaction fetching.
/// See: https://beta-bridge.simplefin.org/info/developers
class SimplefinClient {
  SimplefinClient(this._dio);

  final Dio _dio;

  /// Claim a setup token and receive an access URL.
  ///
  /// The [base64Token] is obtained from simplefin.org by the user.
  /// Returns a [SimplefinAccessUrl] containing credentials for future API calls.
  ///
  /// Throws [SimplefinApiException] on failure:
  /// - 403: Token already claimed or compromised
  Future<SimplefinAccessUrl> claimSetupToken(String base64Token) async {
    final String claimUrl;
    try {
      claimUrl = utf8.decode(base64.decode(base64Token.trim()));
    } on FormatException {
      throw const SimplefinApiException(
        statusCode: 0,
        message: 'Invalid setup token format. '
            'Please copy the entire token from simplefin.org.',
      );
    }

    try {
      final response = await _dio.post<String>(
        claimUrl,
        options: Options(
          responseType: ResponseType.plain,
        ),
      );

      final accessUrlString = response.data?.trim();
      if (accessUrlString == null || accessUrlString.isEmpty) {
        throw const SimplefinApiException(
          statusCode: 0,
          message: 'Empty response from claim URL',
        );
      }

      return SimplefinAccessUrl.parse(accessUrlString);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw const SimplefinApiException(
          statusCode: 403,
          message: 'Token already claimed or compromised. '
              'Please generate a new setup token from simplefin.org.',
        );
      }
      throw SimplefinApiException(
        statusCode: e.response?.statusCode ?? 0,
        message: e.message ?? 'Failed to claim setup token',
      );
    }
  }

  /// Fetch accounts and optionally transactions from SimpleFIN.
  ///
  /// [accessUrl] is the parsed access URL from [claimSetupToken].
  /// [startDate] filters transactions to those posted after this unix timestamp.
  /// [endDate] filters transactions to those posted before this unix timestamp.
  /// [includePending] includes pending transactions if true.
  /// [balancesOnly] skips transaction data if true (faster, lighter).
  ///
  /// Throws [SimplefinApiException] on failure:
  /// - 402: SimpleFIN subscription payment required
  /// - 403: Access revoked, need to re-authenticate
  Future<SimplefinAccountsResponse> getAccounts(
    SimplefinAccessUrl accessUrl, {
    int? startDate,
    int? endDate,
    bool? includePending,
    bool balancesOnly = false,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) queryParams['start-date'] = startDate;
    if (endDate != null) queryParams['end-date'] = endDate;
    if (includePending == true) queryParams['pending'] = 1;
    if (balancesOnly) queryParams['balances-only'] = 1;

    final credentials = base64.encode(
      utf8.encode('${accessUrl.username}:${accessUrl.password}'),
    );

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${accessUrl.baseUrl}/accounts',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          headers: {'Authorization': 'Basic $credentials'},
        ),
      );

      if (response.data == null) {
        throw const SimplefinApiException(
          statusCode: 0,
          message: 'Empty response from SimpleFIN',
        );
      }

      return SimplefinAccountsResponse.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw const SimplefinApiException(
          statusCode: 402,
          message: 'SimpleFIN subscription payment required. '
              'Please check your account at simplefin.org.',
        );
      }
      if (e.response?.statusCode == 403) {
        throw const SimplefinApiException(
          statusCode: 403,
          message: 'Access has been revoked. '
              'Please reconnect your account.',
        );
      }
      throw SimplefinApiException(
        statusCode: e.response?.statusCode ?? 0,
        message: e.message ?? 'Failed to fetch accounts',
      );
    }
  }
}
