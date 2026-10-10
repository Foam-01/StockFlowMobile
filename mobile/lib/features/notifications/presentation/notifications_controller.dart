import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

/// Unread badge. Refreshed on demand (pull to refresh, opening the inbox,
/// marking read); there is no push, so it is not real-time.
final unreadCountProvider = FutureProvider<int>((ref) async {
  // Per user: a different account must never see the previous badge.
  final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
  if (userId == null) return 0;
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});

class InboxState {
  const InboxState({
    required this.items,
    required this.total,
    required this.page,
    this.loadingMore = false,
  });

  final List<AppNotification> items;
  final int total;
  final int page;
  final bool loadingMore;

  bool get hasMore => items.length < total;
  bool get hasUnread => items.any((n) => !n.read);

  InboxState copyWith({
    List<AppNotification>? items,
    int? total,
    int? page,
    bool? loadingMore,
  }) => InboxState(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final inboxProvider = AsyncNotifierProvider.autoDispose<Inbox, InboxState>(
  Inbox.new,
);

class Inbox extends AsyncNotifier<InboxState> {
  NotificationsRepository get _repo =>
      ref.read(notificationsRepositoryProvider);

  @override
  Future<InboxState> build() async {
    ref.watch(authControllerProvider.select((a) => a.value?.id));
    final first = await ref.watch(notificationsRepositoryProvider).list();
    return InboxState(items: first.items, total: first.total, page: 1);
  }

  Future<void> refresh() async {
    ref.invalidate(unreadCountProvider);
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final next = await _repo.list(page: s.page + 1);
      state = AsyncData(
        s.copyWith(
          items: [...s.items, ...next.items],
          total: next.total,
          page: s.page + 1,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// Marks one notice read on the server, then locally.
  Future<void> markRead(String id) async {
    await _repo.markRead(id);
    _update((n) => n.id == id ? n.copyWith(read: true) : n);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    _update((n) => n.copyWith(read: true));
    ref.invalidate(unreadCountProvider);
  }

  void _update(AppNotification Function(AppNotification) f) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(items: s.items.map(f).toList()));
  }
}
