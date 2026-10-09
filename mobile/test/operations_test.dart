import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockflow/core/token_storage.dart';
import 'package:stockflow/features/auth/data/auth_repository.dart';
import 'package:stockflow/features/auth/domain/user.dart';
import 'package:stockflow/features/operations/data/operations_repository.dart';
import 'package:stockflow/features/operations/domain/stock_transaction.dart';
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
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

const _admin = User(
  id: 'u1',
  email: 'admin@stockflow.dev',
  name: 'Admin',
  role: Role.admin,
);
const _staff = User(
  id: 'u2',
  email: 'staff@stockflow.dev',
  name: 'Staff',
  role: Role.staff,
);

const _water = Product(
  id: 'p1',
  sku: 'BEV-001',
  name: 'Drinking water 600ml',
  unit: 'bottle',
  minStock: 24,
  onHand: 26,
);

StockTransaction _tx({
  TxStatus status = TxStatus.draft,
  TxType type = TxType.issue,
  int qty = 4,
  String createdBy = 'u2',
}) => StockTransaction(
  id: 't1',
  type: type,
  status: status,
  referenceNo: 'REQ-1',
  items: [
    TxItem(
      productId: 'p1',
      productName: _water.name,
      sku: _water.sku,
      unit: 'bottle',
      quantity: qty,
    ),
  ],
  createdById: createdBy,
  createdByName: 'Staff',
  createdAt: DateTime(2026, 10, 9, 14, 30),
);

void main() {
  late MockAuth auth;
  late MockProducts products;
  late MockOps ops;

  setUpAll(() => registerFallbackValue(TxType.receive));

  setUp(() {
    auth = MockAuth();
    products = MockProducts();
    ops = MockOps();
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
    ).thenAnswer((_) async => Paged(items: [_tx()], total: 1, page: 1));
    when(() => ops.get('t1')).thenAnswer((_) async => _tx());
  });

  Future<void> pumpAs(WidgetTester tester, User user) async {
    when(() => auth.me()).thenAnswer((_) async => user);
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
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(navTab('Operations'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists operations with status and signed quantity', (
    tester,
  ) async {
    await pumpAs(tester, _admin);
    expect(find.text('REQ-1'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('−4'), findsOneWidget);
  });

  testWidgets('creates an issue draft and blocks issuing above on hand', (
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
    ).thenAnswer((_) async => _tx());
    await pumpAs(tester, _staff);

    await tester.tap(find.byKey(const Key('new_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue'));
    await tester.pumpAndSettle();

    // Saving with no items shows an error, no API call.
    await tester.tap(find.byKey(const Key('save_draft')));
    await tester.pump();
    verifyNever(
      () => ops.create(
        clientUuid: any(named: 'clientUuid'),
        type: any(named: 'type'),
        items: any(named: 'items'),
        referenceNo: any(named: 'referenceNo'),
        note: any(named: 'note'),
      ),
    );

    await tester.tap(find.byKey(const Key('add_item')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drinking water 600ml').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('qty_p1')), '30');
    await tester.tap(find.byKey(const Key('save_draft')));
    await tester.pump();
    expect(find.text('Only 26 bottle on hand'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('qty_p1')), '4');
    await tester.tap(find.byKey(const Key('save_draft')));
    await tester.pumpAndSettle();

    final captured = verify(
      () => ops.create(
        clientUuid: any(named: 'clientUuid'),
        type: TxType.issue,
        items: captureAny(named: 'items'),
        referenceNo: any(named: 'referenceNo'),
        note: any(named: 'note'),
      ),
    ).captured;
    expect(captured.single, [(productId: 'p1', quantity: 4)]);
    // Lands on the detail screen; staff can't confirm.
    expect(find.text('Waiting for an admin to confirm'), findsOneWidget);
    expect(find.byKey(const Key('confirm_tx')), findsNothing);
  });

  testWidgets('admin confirms a draft', (tester) async {
    when(() => ops.confirm('t1'))
        .thenAnswer((_) async => _tx(status: TxStatus.confirmed));
    await pumpAs(tester, _admin);

    await tester.tap(find.text('REQ-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_tx')));
    await tester.pumpAndSettle();

    when(() => ops.get('t1'))
        .thenAnswer((_) async => _tx(status: TxStatus.confirmed));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm').last);
    await tester.pumpAndSettle();

    verify(() => ops.confirm('t1')).called(1);
    expect(find.text('Stock updated'), findsOneWidget);
    expect(find.byKey(const Key('confirm_tx')), findsNothing);
  });

  testWidgets('shows server error when confirm fails', (tester) async {
    when(() => ops.confirm('t1')).thenThrow(Exception('boom'));
    await pumpAs(tester, _admin);
    await tester.tap(find.text('REQ-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_tx')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm').last);
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.byKey(const Key('confirm_tx')), findsOneWidget);
  });
}
