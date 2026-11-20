import 'package:dio/dio.dart';

/// Reads the server's error body (`message`, `code`, `shortfall`) from a Dio failure.
class ServerError implements Exception {
  ServerError(this.message, {this.code, this.shortfall});

  factory ServerError.from(Object e) {
    if (e is DioException) {
      final dynamic d = e.response?.data;
      if (d is Map) {
        return ServerError(
          '${d['message'] ?? 'Something went wrong. Please try again.'}',
          code: d['code'] as String?,
          shortfall: (d['shortfall'] as num?)?.toDouble(),
        );
      }
      return ServerError('Network problem. Check your connection and retry.');
    }
    return ServerError('Something went wrong. Please try again.');
  }

  final String message;
  final String? code;
  final double? shortfall;
}
