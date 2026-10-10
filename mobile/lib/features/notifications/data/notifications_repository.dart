import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../domain/app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => ApiNotificationsRepository(ref.watch(dioProvider)),
);

abstract class NotificationsRepository {
  Future<NotificationPage> list({bool unreadOnly = false, int page = 1});
  Future<int> unreadCount();

  /// Returns the new unread count.
  Future<int> markRead(String id);
  Future<void> markAllRead();
}

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._api);

  final Dio _api;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<NotificationPage> list({bool unreadOnly = false, int page = 1}) =>
      _call(() async {
        final res = await _api.get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: {
            if (unreadOnly) 'unread': true,
            'page': page,
            'limit': 20,
          },
        );
        return NotificationPage.fromJson(res.data!);
      });

  @override
  Future<int> unreadCount() => _call(() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );
    return res.data!['unread'] as int;
  });

  @override
  Future<int> markRead(String id) => _call(() async {
    final res = await _api.post<Map<String, dynamic>>(
      '/notifications/$id/read',
    );
    return res.data!['unread'] as int;
  });

  @override
  Future<void> markAllRead() =>
      _call(() => _api.post<void>('/notifications/read-all'));
}
