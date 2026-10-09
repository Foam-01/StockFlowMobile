import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockflow/core/errors.dart';
import 'package:stockflow/core/token_storage.dart';
import 'package:stockflow/features/auth/data/auth_repository.dart';
import 'package:stockflow/features/auth/domain/user.dart';
import 'package:stockflow/features/history/data/history_repository.dart';
import 'package:stockflow/features/history/domain/movement.dart';
import 'package:stockflow/features/history/presentation/product_history_screen.dart';
import 'package:stockflow/features/operations/domain/stock_transaction.dart';
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class MockAuth extends Mock implements AuthRepository {}

class MockProducts extends Mock implements ProductsRepository {}

class MockHistory extends Mock implements HistoryRepository {}

class MemoryTokenStorage implements TokenStorage {
  String? token = 'saved';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

const _water = Product(
  id: 'p1',
  sku: 'BEV-001',
  name: 'Drinking water 600ml',
  unit: 'bottle',
  minStock: 24,
  onHand: 26,
);

Movement _m(int i, TxType type, int change, int balance) => Movement(
  transactionId: 't$i',
  type: type,
  change: change,
  balanceAfter: balance,
  confirmedAt: DateTime(2026, 10, 9, 10, i),
  createdBy: 'Staff',
  confirmedBy: 'Admin',
  referenceNo: 'REF-$i',
);

void main() {
  late MockAuth auth;
  late MockProducts products;
  late MockHistory history;

  setUp(() {
    auth = MockAuth();
    products = MockProducts();
    history = MockHistory();
    when(() => auth.me()).thenAnswer(
      (_) async => const User(
        id: 'u1',
        email: 'admin@stockflow.dev',
        name: 'Admin',
        role: Role.admin,
      ),
    );
    when(() => products.categories()).thenAnswer((_) async => []);
    when(
      () => products.list(
        query: any(named: 'query'),
        categoryId: any(named: 'categoryId'),
        lowStock: any(named: 'lowStock'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Paged(items: [_water], total: 1, page: 1));
    when(() => products.get('p1')).thenAnswer((_) async => _water);
  });

  Future<void> openProduct(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          dashboardRepositoryProvider.overrideWithValue(
            EmptyDashboardRepository(),
          ),
          productsRepositoryProvider.overrideWithValue(products),
          historyRepositoryProvider.overrideWithValue(history),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(navTab('Products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drinking water 600ml'));
    await tester.pumpAndSettle();
  }

  testWidgets('product detail shows recent movements with balances', (
    tester,
  ) async {
    when(() => history.movements('p1', limit: 5)).thenAnswer(
      (_) async => MovementPage(
        items: [_m(2, TxType.issue, -4, 26), _m(1, TxType.receive, 30, 30)],
        total: 2,
        page: 1,
        unit: 'bottle',
        onHand: 26,
      ),
    );
    await openProduct(tester);

    expect(find.text('Recent movements'), findsOneWidget);
    expect(find.text('REF-2'), findsOneWidget);
    expect(find.text('−4'), findsOneWidget);
    expect(find.text('bal. 26 bottle'), findsOneWidget);
    expect(find.text('+30'), findsOneWidget);
    expect(find.text('bal. 30 bottle'), findsOneWidget);
    expect(find.text('View all (2)'), findsOneWidget);
  });

  testWidgets('history screen pages through all movements', (tester) async {
    final all = [for (var i = 25; i >= 1; i--) _m(i, TxType.receive, 1, i)];
    when(() => history.movements('p1', limit: 5)).thenAnswer(
      (_) async => MovementPage(
        items: all.take(5).toList(),
        total: 25,
        page: 1,
        unit: 'bottle',
        onHand: 25,
      ),
    );
    when(() => history.movements('p1', page: any(named: 'page'), limit: 20))
        .thenAnswer((inv) async {
          final page = inv.namedArguments[#page] as int;
          return MovementPage(
            items: all.skip((page - 1) * 20).take(20).toList(),
            total: 25,
            page: page,
            unit: 'bottle',
            onHand: 25,
          );
        });
    await openProduct(tester);

    await tester.ensureVisible(find.byKey(const Key('view_history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view_history')));
    await tester.pumpAndSettle();

    expect(find.text('Stock history'), findsOneWidget);
    expect(find.text('25 movements · on hand 25 bottle'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('REF-1'),
      400,
      scrollable: find.descendant(
        of: find.byType(ProductHistoryScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('REF-1'), findsOneWidget);
    verify(() => history.movements('p1', page: 2, limit: 20)).called(1);
  });

  testWidgets('shows retry when movements fail to load', (tester) async {
    var calls = 0;
    when(() => history.movements('p1', limit: 5)).thenAnswer((_) async {
      if (calls++ == 0) throw ApiException('Cannot reach the server.');
      return const MovementPage(
        items: [],
        total: 0,
        page: 1,
        unit: 'bottle',
        onHand: 26,
      );
    });
    await openProduct(tester);

    expect(find.text('Could not load movements'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No confirmed movements yet'), findsOneWidget);
  });
}
