import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockflow/core/token_storage.dart';
import 'package:stockflow/features/auth/data/auth_repository.dart';
import 'package:stockflow/features/auth/domain/user.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/dashboard/domain/dashboard.dart';
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/work_orders/data/work_orders_repository.dart';
import 'package:stockflow/features/work_orders/domain/work_order.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class MockAuth extends Mock implements AuthRepository {}

class MockWo extends Mock implements WorkOrdersRepository {}

class MockProducts extends Mock implements ProductsRepository {}

class MemoryTokenStorage implements TokenStorage {
  String? token = 'saved';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

/// Empty dashboard plus work-order counts.
class JobsDashboard extends EmptyDashboardRepository {
  @override
  Future<DashboardSummary> summary() async {
    final base = await super.summary();
    return DashboardSummary(
      totals: base.totals,
      flow: base.flow,
      needsAttention: base.needsAttention,
      recentActivity: base.recentActivity,
      workOrders: const WorkOrderCounts({
        'OPEN': 2,
        'IN_PROGRESS': 1,
        'NEEDS_REVISION': 1,
        'SUBMITTED': 3,
        'APPROVED': 5,
        'CANCELLED': 0,
      }, 1),
    );
  }
}

WorkOrderSummary _job(String id, String title) => WorkOrderSummary.fromJson({
  'id': id,
  'code': 'WO-$id',
  'title': title,
  'siteName': 'Site',
  'status': 'OPEN',
  'priority': 'NORMAL',
  'checklistDone': 0,
  'checklistTotal': 0,
});

void main() {
  late MockAuth auth;
  late MockWo wo;
  late MockProducts products;
  late MemoryTokenStorage storage;

  setUpAll(() => registerFallbackValue(<WoStatus>{}));

  setUp(() {
    auth = MockAuth();
    wo = MockWo();
    products = MockProducts();
    storage = MemoryTokenStorage();
    when(() => products.categories()).thenAnswer((_) async => []);
    when(
      () => products.list(
        query: any(named: 'query'),
        categoryId: any(named: 'categoryId'),
        lowStock: any(named: 'lowStock'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));
    when(
      () => wo.list(
        statuses: any(named: 'statuses'),
        query: any(named: 'query'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          dashboardRepositoryProvider.overrideWithValue(JobsDashboard()),
          workOrdersRepositoryProvider.overrideWithValue(wo),
          productsRepositoryProvider.overrideWithValue(products),
          tokenStorageProvider.overrideWithValue(storage),
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  User user(String id, Role role) =>
      User(id: id, email: '$id@x.dev', name: id, role: role);

  testWidgets('supervisor dashboard has no stock-writing shortcuts', (
    tester,
  ) async {
    when(() => auth.me()).thenAnswer((_) async => user('sup', Role.supervisor));
    await pump(tester);
    await tester.tap(navTab('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick_receive')), findsNothing);
    expect(find.byKey(const Key('quick_issue')), findsNothing);
    expect(find.byKey(const Key('quick_scan')), findsOneWidget);
  });

  testWidgets('admin dashboard shows field jobs; a count opens that list', (
    tester,
  ) async {
    when(() => auth.me()).thenAnswer((_) async => user('admin', Role.admin));
    await pump(tester);

    expect(find.byKey(const Key('quick_receive')), findsOneWidget);
    expect(find.byKey(const Key('jobs_card')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('jobs_card')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    ); // active = 2 + 1 + 1

    await tester.tap(find.byKey(const Key('jobs_to_review')));
    await tester.pumpAndSettle();
    verify(
      () => wo.list(
        statuses: {WoStatus.submitted},
        query: any(named: 'query'),
        page: 1,
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });

  testWidgets("switching technicians never shows the previous user's jobs", (
    tester,
  ) async {
    var current = user('t1', Role.technician);
    when(() => auth.me()).thenAnswer((_) async => current);
    when(() => auth.login(any(), any()))
        .thenAnswer((_) async => ('token-2', user('t2', Role.technician)));
    var call = 0;
    when(
      () => wo.list(
        statuses: any(named: 'statuses'),
        query: any(named: 'query'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => Paged(
        items: [call++ == 0 ? _job('1', 'Job of T1') : _job('2', 'Job of T2')],
        total: 1,
        page: 1,
      ),
    );
    await pump(tester);
    expect(find.text('Job of T1'), findsOneWidget);

    await tester.tap(navTab('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign_out')));
    await tester.pumpAndSettle();

    current = user('t2', Role.technician);
    await tester.tap(find.byKey(const Key('demo_technician')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Job of T1'), findsNothing);
    expect(find.text('Job of T2'), findsOneWidget);
  });

  testWidgets('switching to Thai in Profile translates the app', (
    tester,
  ) async {
    when(() => auth.me()).thenAnswer((_) async => user('admin', Role.admin));
    await pump(tester);
    await tester.tap(find.byKey(const Key('open_profile')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ไทย'));
    await tester.pumpAndSettle();
    expect(find.text('ออกจากระบบ'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    expect(navTab('ภาพรวม'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
  });
}
