import 'package:dio/dio.dart';

/// User-facing error derived from a failed API call.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isNetwork = false});

  final String message;
  final int? statusCode;

  /// The request never got an answer (offline, timeout, server down).
  /// Safe to retry later; the server may or may not have seen it.
  final bool isNetwork;

  /// Worth retrying later: no answer, or a temporary server failure.
  bool get isTransient =>
      isNetwork || (statusCode != null && statusCode! >= 500);

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return ApiException('Something went wrong');

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return ApiException(
          'Cannot reach the server. Check your connection.',
          isNetwork: true,
        );
      default:
        break;
    }

    final res = error.response;
    // NestJS errors look like { message: string | string[], statusCode }.
    final data = res?.data;
    var message = 'Request failed (${res?.statusCode ?? 'no response'})';
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      message = m is List ? m.join('\n') : m.toString();
    }
    return ApiException(message, statusCode: res?.statusCode);
  }

  @override
  String toString() => message;
}
