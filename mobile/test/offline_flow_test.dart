import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockflow/core/errors.dart';
import 'package:stockflow/core/token_storage.dart';
import 'package:stockflow/features/auth/data/auth_repository.dart';
import 'package:stockflow/features/auth/domain/user.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/offline/presentation/sync_controller.dart';
import 'package:stockflow/features/operations/data/operations_repository.dart';
import 'package:stockflow/features/operations/domain/stock_transaction.dart';
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class MockAuth extends Mock implements AuthRepository {}

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

const _water = Product(
  id: 'p1',
  sku: 'BEV-001',
  name: 'Drinking water 600ml',
  unit: 'bottle',
  minStock: 24,
  onHand: 26,
);

StockTransaction _created(String id) => StockTransaction(
  id: id,
  type: TxType.receive,
  status: TxStatus.draft,
  items: const [
    TxItem(
      productId: 'p1',
      productName: 'Drinking water 600ml',
      sku: 'BEV-001',
      unit: 'bottle',
      quantity: 1,
    ),
  ],
  createdById: 'u2',
  createdByName: 'Staff',
  createdAt: DateTime(2026, 10, 10),
);

void main() {
  late MockAuth auth;
  late MockProducts products;
  late MockOps ops;
  late bool serverUp;
  late List<String> sentUuids;

  setUpAll(() => registerFallbackValue(TxType.receive));

  setUp(() {
    serverUp = false;
    sentUuids = [];
    auth = MockAuth();
    products = MockProducts();
    ops = MockOps();
    when(() => auth.me()).thenAnswer(
      (_) async => const User(
        id: 'u2',
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
    ).thenAnswer((_) async => const Paged(items: [_water], total: 1, page: 1));
    when(
      () => ops.list(
        status: any(named: 'status'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));
    when(
      () => ops.create(
        clientUuid: any(named: 'clientUuid'),
        type: any(named: 'type'),
        items: any(named: 'items'),
        referenceNo: any(named: 'referenceNo'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((inv) async {
      sentUuids.add(inv.namedArguments[#clientUuid] as String);
      if (!serverUp) {
        throw ApiException('Cannot reach the server.', isNetwork: true);
      }
      return _created('t-new');
    });
  });

  Future<void> pumpApp(WidgetTester tester, {bool online = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          dashboardRepositoryProvider.overrideWithValue(
            EmptyDashboardRepository(),
          ),
          productsRepositoryProvider.overrideWithValue(products),
          operationsRepositoryProvider.overrideWithValue(ops),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
          connectivityProvider.overrideWith((ref) => Stream.value(online)),
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(navTab('Operations'));
    await tester.pumpAndSettle();
  }

  Future<void> createReceiveDraft(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('new_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Reference no. (optional)'),
      'PO-OFF-1',
    );
    await tester.tap(find.byKey(const Key('add_item')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drinking water 600ml').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_draft')));
    await tester.pumpAndSettle();
  }

  testWidgets('offline save queues the document, sync sends it once online', (
    tester,
  ) async {
    await pumpApp(tester);
    await createReceiveDraft(tester);

    // Back on the list, queued locally with a badge on the tab.
    expect(
      find.text('Saved on this device. It will sync when online.'),
      findsOneWidget,
    );
    expect(find.text('Waiting to sync (1)'), findsOneWidget);
    expect(find.text('PO-OFF-1'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app_nav')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    // Server still down: stays queued.
    await tester.tap(find.byKey(const Key('sync_now')));
    await tester.pumpAndSettle();
    expect(find.text('Waiting to sync (1)'), findsOneWidget);

    // Server back: sync succeeds and the queue empties.
    serverUp = true;
    await tester.tap(find.byKey(const Key('sync_now')));
    await tester.pumpAndSettle();
    expect(find.text('1 synced'), findsOneWidget);
    expect(find.text('Waiting to sync (1)'), findsNothing);

    // Every attempt reused the same clientUuid → no duplicates on the server.
    expect(sentUuids.length, 3); // first save + 2 syncs
    expect(sentUuids.toSet().length, 1);
  });

  testWidgets('rejected item is marked failed and can be discarded', (
    tester,
  ) async {
    await pumpApp(tester);
    await createReceiveDraft(tester);

    when(
      () => ops.create(
        clientUuid: any(named: 'clientUuid'),
        type: any(named: 'type'),
        items: any(named: 'items'),
        referenceNo: any(named: 'referenceNo'),
        note: any(named: 'note'),
      ),
    ).thenThrow(
      ApiException('One or more products do not exist', statusCode: 400),
    );
    await tester.tap(find.byKey(const Key('sync_now')));
    await tester.pumpAndSettle();

    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('One or more products do not exist'), findsOneWidget);

    await tester.tap(find.text('Failed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Failed'), findsNothing);
    expect(find.textContaining('Waiting to sync'), findsNothing);
  });

  testWidgets('shows an offline banner when the device has no network', (
    tester,
  ) async {
    await pumpApp(tester, online: false);
    expect(find.byKey(const Key('offline_banner')), findsOneWidget);
  });

  testWidgets('server errors other than network are not queued', (
    tester,
  ) async {
    when(
      () => ops.create(
        clientUuid: any(named: 'clientUuid'),
        type: any(named: 'type'),
        items: any(named: 'items'),
        referenceNo: any(named: 'referenceNo'),
        note: any(named: 'note'),
      ),
    ).thenThrow(ApiException('Validation failed', statusCode: 400));
    await pumpApp(tester);
    await createReceiveDraft(tester);

    expect(find.text('Validation failed'), findsOneWidget);
    expect(find.textContaining('Waiting to sync'), findsNothing);
    // Still on the form so the user can fix it.
    expect(find.byKey(const Key('save_draft')), findsOneWidget);
  });
}
