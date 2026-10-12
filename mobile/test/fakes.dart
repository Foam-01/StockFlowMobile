import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/dashboard/domain/dashboard.dart';
import 'package:stockflow/features/notifications/data/notifications_repository.dart';
import 'package:stockflow/features/notifications/domain/app_notification.dart';
import 'package:stockflow/core/errors.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/work_orders/data/work_order_offline_store.dart';
import 'package:stockflow/features/work_orders/data/work_orders_repository.dart';
import 'package:stockflow/features/work_orders/domain/work_order.dart';

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

/// A tiny in-memory server for one in-progress job with two items.
/// Behaves like the API: saves every detail it returns (the cache hook),
/// refuses stale edits with 409, and can be switched "offline".
class FakeServer implements WorkOrdersRepository {
  FakeServer(this.store);

  final WoOfflineStore store;
  bool offline = false;
  final done = <String, bool>{'item0': false, 'item1': false};
  final notes = <String, String?>{};
  final calls = <Map<String, Object?>>[];

  Map<String, dynamic> get json => {
    'id': 'wo1',
    'code': 'WO-00001',
    'title': 'Install AC',
    'siteName': 'Site',
    'status': 'IN_PROGRESS',
    'priority': 'NORMAL',
    'requiredEvidence': <String>[],
    'createdAt': '2026-10-10T08:00:00.000Z',
    'checklist': [
      for (final id in done.keys)
        {
          'id': id,
          'title': id,
          'required': true,
          'done': done[id],
          'note': notes[id],
        },
    ],
    'materials': <dynamic>[],
    'evidence': <dynamic>[],
    'stockTransactions': <dynamic>[],
    'allowedActions': ['updateChecklist', 'submit'],
    'submissionProblems': <String>[],
  };

  void _online() {
    if (offline) throw ApiException('offline', isNetwork: true);
  }

  Future<WorkOrder> _answer() async {
    await store.cache(json);
    return WorkOrder.fromJson(json);
  }

  @override
  Future<WorkOrder> get(String id) async {
    _online();
    return _answer();
  }

  @override
  Future<WorkOrder> setChecklistItem(
    String id,
    String itemId, {
    required bool done,
    String? note,
    bool? expectedDone,
  }) async {
    _online();
    calls.add({'item': itemId, 'done': done, 'expected': expectedDone});
    if (expectedDone != null &&
        this.done[itemId] != expectedDone &&
        this.done[itemId] != done) {
      throw ApiException(
        'Checklist item was changed on the server',
        statusCode: 409,
      );
    }
    this.done[itemId] = done;
    if (note != null) notes[itemId] = note.isEmpty ? null : note;
    return _answer();
  }

  @override
  Future<Paged<WorkOrderSummary>> list({
    Set<WoStatus> statuses = const {},
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    _online();
    return Paged(
      items: [
        WorkOrderSummary.fromJson({
          ...json,
          'checklistDone': done.values.where((d) => d).length,
          'checklistTotal': done.length,
        }),
      ],
      total: 1,
      page: 1,
    );
  }

  @override
  Future<List<WoEvent>> events(String id) async => [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
