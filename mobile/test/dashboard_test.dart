import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockflow/core/errors.dart';
import 'package:stockflow/core/token_storage.dart';
import 'package:stockflow/features/auth/data/auth_repository.dart';
import 'package:stockflow/features/auth/domain/user.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/dashboard/domain/dashboard.dart';
import 'package:stockflow/features/operations/data/operations_repository.dart';
import 'package:stockflow/features/operations/domain/stock_transaction.dart';
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/notifications/data/notifications_repository.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class MockAuth extends Mock implements AuthRepository {}

class MockDashboard extends Mock implements DashboardRepository {}

class MockProducts extends Mock implements ProductsRepository {}

class MockOps extends Mock implements OperationsRepository {}

class MemoryTokenStorage implements TokenStorage {
  String? token = 'saved';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

final _summary = DashboardSummary(
  totals: const DashboardTotals(
    products: 9,
    unitsOnHand: 59,
    lowStock: 2,
    outOfStock: 6,
    pendingDrafts: 3,
  ),
  flow: [
    for (var i = 6; i >= 0; i--)
      DayFlow(
        date: DateTime(2026, 10, 9).subtract(Duration(days: i)),
        received: i == 0 ? 67 : 0,
        issued: i == 0 ? 8 : (i == 2 ? 5 : 0),
      ),
  ],
  needsAttention: const [
    AttentionItem(
      id: 'p2',
      sku: 'BEV-002',
      name: 'Green tea 500ml',
      unit: 'bottle',
      onHand: 0,
      minStock: 12,
    ),
  ],
  recentActivity: [
    RecentActivity(
      id: 't1',
      type: TxType.receive,
      referenceNo: 'PO-1',
      confirmedAt: DateTime(2026, 10, 9, 15),
      confirmedBy: 'Admin',
      itemCount: 2,
    ),
  ],
);

void main() {
  late MockAuth auth;
  late MockDashboard dashboard;
  late MockProducts products;
  late MockOps ops;

  setUpAll(() => registerFallbackValue(TxStatus.draft));

  setUp(() {
    auth = MockAuth();
    dashboard = MockDashboard();
    products = MockProducts();
    ops = MockOps();
    when(() => auth.me()).thenAnswer(
      (_) async => const User(
        id: 'u1',
        email: 'admin@stockflow.dev',
        name: 'Admin',
        role: Role.admin,
      ),
    );
    when(() => dashboard.summary()).thenAnswer((_) async => _summary);
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
      () => ops.list(
        status: any(named: 'status'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          dashboardRepositoryProvider.overrideWithValue(dashboard),
          productsRepositoryProvider.overrideWithValue(products),
          operationsRepositoryProvider.overrideWithValue(ops),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows KPIs, weekly totals and lists', (tester) async {
    await pumpApp(tester);

    expect(find.text('Hello, Admin'), findsOneWidget);
    expect(find.text('59'), findsOneWidget); // units on hand
    expect(find.text('6'), findsOneWidget); // out of stock
    expect(find.text('3 drafts waiting for confirmation'), findsOneWidget);
    expect(find.text('67 received · 13 issued'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('PO-1'), 300);
    expect(find.text('Green tea 500ml'), findsOneWidget);
    expect(find.text('PO-1'), findsOneWidget);
  });

  testWidgets('chart readout follows the tapped day; table view', (
    tester,
  ) async {
    await pumpApp(tester);

    // Today is selected by default.
    expect(find.text('Fri 9/10'), findsOneWidget);
    expect(find.text('67'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Wed 7/10')));
    await tester.pump();
    expect(find.text('Wed 7/10'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flow_table_toggle')));
    await tester.pump();
    expect(find.text('Received'), findsWidgets);
    expect(find.text('Thu 8/10'), findsOneWidget);
  });

  testWidgets('pending drafts opens operations filtered to Draft', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('pending_drafts')));
    await tester.pumpAndSettle();

    expect(find.text('Stock operations'), findsOneWidget);
    verify(
      () => ops.list(
        status: TxStatus.draft,
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });

  testWidgets('low stock tile opens products filtered to low stock', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('tile_low')));
    await tester.pumpAndSettle();

    verify(
      () => products.list(
        query: any(named: 'query'),
        categoryId: any(named: 'categoryId'),
        lowStock: true,
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });

  testWidgets('shows error with retry', (tester) async {
    var calls = 0;
    when(() => dashboard.summary()).thenAnswer((_) async {
      if (calls++ == 0) throw ApiException('Cannot reach the server.');
      return _summary;
    });
    await pumpApp(tester);

    expect(find.text('Cannot reach the server.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('59'), findsOneWidget);
  });
}
