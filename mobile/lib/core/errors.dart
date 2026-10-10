import 'package:dio/dio.dart';

import 'l10n.dart';

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
    if (error is! DioException) return ApiException(l10nNow.somethingWrong);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return ApiException(l10nNow.cannotReach, isNetwork: true);
      default:
        break;
    }

    final res = error.response;
    // NestJS errors look like { message: string | string[], statusCode }.
    final data = res?.data;
    var message = l10nNow.requestFailed(
      '${res?.statusCode ?? l10nNow.noResponse}',
    );
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      message = m is List ? m.join('\n') : m.toString();
    }
    // e.g. submit: { message, problems: ["Checklist: ... is not done", ...] }
    if (data is Map && data['problems'] is List) {
      final problems = (data['problems'] as List).map((p) => '• $p');
      message = [message, ...problems].join('\n');
    }
    return ApiException(message, statusCode: res?.statusCode);
  }

  @override
  String toString() => message;
}
