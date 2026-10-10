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
import 'package:stockflow/features/operations/data/operations_repository.dart';
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/scanner/presentation/barcode_lookup.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/notifications/data/notifications_repository.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class MockAuth extends Mock implements AuthRepository {}

class MockProducts extends Mock implements ProductsRepository {}

class MockHistory extends Mock implements HistoryRepository {}

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

const _water = Product(
  id: 'p1',
  sku: 'BEV-001',
  barcode: '8850999320014',
  name: 'Drinking water 600ml',
  unit: 'bottle',
  minStock: 24,
  onHand: 26,
);

void main() {
  late MockAuth auth;
  late MockProducts products;
  late MockHistory history;
  late List<String?> scans; // queued results from the fake scanner

  setUp(() {
    scans = [];
    auth = MockAuth();
    products = MockProducts();
    history = MockHistory();
    when(() => auth.me()).thenAnswer(
      (_) async => const User(
        id: 'u1',
        email: 'staff@stockflow.dev',
        name: 'Staff',
        role: Role.staff,
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
    ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));
    when(() => products.get('p1')).thenAnswer((_) async => _water);
    when(() => products.getByBarcode('8850999320014'))
        .thenAnswer((_) async => _water);
    when(() => products.getByBarcode('0000'))
        .thenThrow(ApiException('Not found', statusCode: 404));
    when(
      () => history.movements(
        any(),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => const MovementPage(
        items: [],
        total: 0,
        page: 1,
        unit: 'bottle',
        onHand: 26,
      ),
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final ops = MockOps();
    when(
      () => ops.list(
        status: any(named: 'status'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));

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
          operationsRepositoryProvider.overrideWithValue(ops),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          barcodeScannerProvider.overrideWithValue(
            (context, {title}) async => scans.removeAt(0),
          ),
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(navTab('Products'));
    await tester.pumpAndSettle();
  }

  testWidgets('scanning a known barcode opens the product', (tester) async {
    scans.add('8850999320014');
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('scan_product')));
    await tester.pumpAndSettle();

    expect(find.text('Drinking water 600ml'), findsOneWidget);
    expect(find.text('BEV-001'), findsOneWidget);
  });

  testWidgets('unknown barcode shows a message and stays put', (tester) async {
    scans.add('0000');
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('scan_product')));
    await tester.pumpAndSettle();

    expect(find.text('No product with barcode 0000'), findsOneWidget);
    expect(find.text('No products yet'), findsOneWidget);
  });

  testWidgets('cancelling the scanner does nothing', (tester) async {
    scans.add(null);
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('scan_product')));
    await tester.pumpAndSettle();

    verifyNever(() => products.getByBarcode(any()));
  });

  testWidgets('scanning in a new operation adds then increments the item', (
    tester,
  ) async {
    scans.addAll(['8850999320014', '8850999320014']);
    await pumpApp(tester);
    await tester.tap(navTab('Operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scan_item')));
    await tester.pumpAndSettle();
    expect(find.text('Drinking water 600ml'), findsOneWidget);
    expect(find.text('Added Drinking water 600ml'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scan_item')));
    await tester.pumpAndSettle();
    final qty = tester.widget<TextField>(find.byKey(const Key('qty_p1')));
    expect(qty.controller!.text, '2');
  });
}
