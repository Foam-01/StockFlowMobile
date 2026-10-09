import 'package:dio/dio.dart';

/// User-facing error derived from a failed API call.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return ApiException('Something went wrong');

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return ApiException('Cannot reach the server. Check your connection.');
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
