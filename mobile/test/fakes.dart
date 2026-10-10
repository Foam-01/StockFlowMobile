import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/dashboard/domain/dashboard.dart';
import 'package:stockflow/features/notifications/data/notifications_repository.dart';
import 'package:stockflow/features/notifications/domain/app_notification.dart';

/// Dashboard with no data, for tests that don't care about it.
class EmptyDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSummary> summary() async => DashboardSummary(
    totals: const DashboardTotals(
      products: 0,
      unitsOnHand: 0,
      lowStock: 0,
      outOfStock: 0,
      pendingDrafts: 0,
    ),
    flow: [
      for (var i = 6; i >= 0; i--)
        DayFlow(
          date: DateTime(2026, 10, 9).subtract(Duration(days: i)),
          received: 0,
          issued: 0,
        ),
    ],
    needsAttention: const [],
    recentActivity: const [],
  );
}

/// The bottom-navigation tab with [label] (avoids clashing with page text).
Finder navTab(String label) => find.descendant(
  of: find.byKey(const Key('app_nav')),
  matching: find.text(label),
);

/// In-memory inbox that behaves like the API (per-call, no network).
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository([List<AppNotification>? items])
    : items = items ?? [];

  final List<AppNotification> items;
  final List<String> markedRead = [];

  int get _unread => items.where((n) => !n.read).length;

  @override
  Future<NotificationPage> list({bool unreadOnly = false, int page = 1}) async {
    final shown = unreadOnly ? items.where((n) => !n.read).toList() : items;
    return NotificationPage(
      items: List.of(shown),
      total: shown.length,
      unread: _unread,
      page: page,
    );
  }

  @override
  Future<int> unreadCount() async => _unread;

  @override
  Future<int> markRead(String id) async {
    markedRead.add(id);
    final i = items.indexWhere((n) => n.id == id);
    items[i] = items[i].copyWith(read: true);
    return _unread;
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(read: true);
    }
  }
}
