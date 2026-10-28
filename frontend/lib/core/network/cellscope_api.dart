import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class CellScopeApi {
  final String? baseUrl;
  final Duration timeout;
  final Dio _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null,
    ),
  );

  CellScopeApi({String? url, this.timeout = const Duration(seconds: 25)})
    : baseUrl = url ?? dotenv.env['API_BASE_URL'];

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final cancelToken = CancelToken();
    try {
      return await _perform(path, method, body, cancelToken).timeout(timeout);
    } on TimeoutException {
      cancelToken.cancel('Request timed out');
      throw ApiException(
        'The server took too long. Check your connection and retry.',
      );
    } on DioException catch (error) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw ApiException(
            'The server took too long. Check your connection and retry.',
          );
        case DioExceptionType.connectionError:
          throw ApiException(
            'Cannot reach the server. Please try again later.',
          );
        default:
          throw ApiException(
            'The connection closed unexpectedly. Please retry.',
          );
      }
    } on FormatException {
      throw ApiException('The server returned an unexpected response.');
    }
  }

  Future<Map<String, dynamic>> _perform(
    String path,
    String method,
    Map<String, dynamic>? body,
    CancelToken cancelToken,
  ) async {
    final response = await _client.request<String>(
      '$baseUrl$path',
      data: body,
      options: Options(method: method),
      cancelToken: cancelToken,
    );
    final decoded = jsonDecode(response.data ?? '');
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiException(
        detail is String
            ? detail
            : 'The measurements could not be accepted. Check all 30 fields.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  void close() => _client.close(force: true);
}
