import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'token_storage.dart';

/// Bumped every time the API rejects our token (401).
/// The auth controller listens to this and signs the user out.
final sessionExpiredProvider = NotifierProvider<SessionExpired, int>(
  SessionExpired.new,
);

class SessionExpired extends Notifier<int> {
  @override
  int build() => 0;

  void signal() => state++;
}

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        final isLogin = error.requestOptions.path.startsWith('/auth/login');
        if (error.response?.statusCode == 401 && !isLogin) {
          ref.read(sessionExpiredProvider.notifier).signal();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});
