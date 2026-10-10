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
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/notifications/data/notifications_repository.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProductsRepository extends Mock implements ProductsRepository {}

class MockHistoryRepository extends Mock implements HistoryRepository {}

class MemoryTokenStorage implements TokenStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

const _admin = User(
  id: '1',
  email: 'admin@stockflow.dev',
  name: 'Admin',
  role: Role.admin,
);

const _beverages = Category(id: 'c1', name: 'Beverages');

const _water = Product(
  id: 'p1',
  sku: 'BEV-001',
  name: 'Drinking water 600ml',
  unit: 'bottle',
  minStock: 24,
  onHand: 30,
  category: _beverages,
);
const _tea = Product(
  id: 'p2',
  sku: 'BEV-002',
  name: 'Green tea 500ml',
  unit: 'bottle',
  minStock: 12,
  onHand: 0,
  category: _beverages,
);

void main() {
  late MockAuthRepository auth;
  late MockProductsRepository products;
  late MemoryTokenStorage storage;
  late MockHistoryRepository history;

  setUp(() {
    history = MockHistoryRepository();
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
        onHand: 0,
      ),
    );
    auth = MockAuthRepository();
    products = MockProductsRepository();
    storage = MemoryTokenStorage();

    when(() => products.categories()).thenAnswer((_) async => [_beverages]);
    when(
      () => products.list(
        query: any(named: 'query'),
        categoryId: any(named: 'categoryId'),
        lowStock: any(named: 'lowStock'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => const Paged(items: [_water, _tea], total: 2, page: 1),
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
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
          tokenStorageProvider.overrideWithValue(storage),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpSignedIn(WidgetTester tester) async {
    storage.token = 'saved';
    when(() => auth.me()).thenAnswer((_) async => _admin);
    await pumpApp(tester);
    await tester.tap(navTab('Products'));
    await tester.pumpAndSettle();
  }

  group('login', () {
    final email = find.byKey(const Key('login_email'));
    final password = find.byKey(const Key('login_password'));
    final submit = find.byKey(const Key('login_submit'));

    testWidgets('shows login when there is no saved token', (tester) async {
      await pumpApp(tester);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('validates empty and malformed fields', (tester) async {
      await pumpApp(tester);

      await tester.tap(submit);
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);

      await tester.enterText(email, 'not-an-email');
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('Please enter a valid email'), findsOneWidget);
      verifyNever(() => auth.login(any(), any()));
    });

    testWidgets('shows server error on wrong password', (tester) async {
      when(
        () => auth.login(any(), any()),
      ).thenThrow(ApiException('Invalid email or password', statusCode: 401));
      await pumpApp(tester);

      await tester.enterText(email, 'admin@stockflow.dev');
      await tester.enterText(password, 'wrong');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(storage.token, isNull);
    });

    testWidgets('login opens products, sign out returns to login', (
      tester,
    ) async {
      when(() => auth.login('admin@stockflow.dev', 'Admin1234!'))
          .thenAnswer((_) async => ('jwt-token', _admin));
      await pumpApp(tester);

      await tester.tap(find.text('Admin')); // demo chip fills the form
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(storage.token, 'jwt-token');
      expect(find.text('Hello, Admin'), findsOneWidget); // lands on dashboard
      await tester.tap(navTab('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Drinking water 600ml'), findsOneWidget);

      // Admins open Profile from the dashboard avatar (tab bar is full).
      await tester.tap(navTab('Dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign_out')));
      await tester.pumpAndSettle();
      expect(storage.token, isNull);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('restores session from saved token', (tester) async {
      await pumpSignedIn(tester);
      expect(find.text('Products'), findsWidgets);
      expect(find.text('Sign in'), findsNothing);
    });
  });

  group('products', () {
    testWidgets('lists products with stock levels', (tester) async {
      await pumpSignedIn(tester);

      expect(find.text('2 products'), findsOneWidget);
      expect(find.text('Drinking water 600ml'), findsOneWidget);
      expect(find.text('BEV-001 · Beverages'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Green tea 500ml'), findsOneWidget);
    });

    testWidgets('search is debounced and sent to the API', (tester) async {
      await pumpSignedIn(tester);

      await tester.enterText(find.byKey(const Key('product_search')), 'tea');
      await tester.pump(const Duration(milliseconds: 100));
      verifyNever(
        () => products.list(
          query: 'tea',
          categoryId: any(named: 'categoryId'),
          lowStock: any(named: 'lowStock'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      verify(
        () => products.list(
          query: 'tea',
          categoryId: any(named: 'categoryId'),
          lowStock: false,
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    testWidgets('low stock filter is sent to the API', (tester) async {
      await pumpSignedIn(tester);
      await tester.tap(find.byKey(const Key('filter_low_stock')));
      await tester.pumpAndSettle();
      verify(
        () => products.list(
          query: any(named: 'query'),
          categoryId: any(named: 'categoryId'),
          lowStock: true,
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    testWidgets('shows empty state when nothing matches', (tester) async {
      when(
        () => products.list(
          query: any(named: 'query'),
          categoryId: any(named: 'categoryId'),
          lowStock: any(named: 'lowStock'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));
      await pumpSignedIn(tester);
      expect(find.text('No products yet'), findsOneWidget);
    });

    testWidgets('shows error state and retries', (tester) async {
      var calls = 0;
      when(
        () => products.list(
          query: any(named: 'query'),
          categoryId: any(named: 'categoryId'),
          lowStock: any(named: 'lowStock'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw ApiException('Cannot reach the server.');
        return const Paged(items: [_water], total: 1, page: 1);
      });
      await pumpSignedIn(tester);

      expect(find.text('Cannot reach the server.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Drinking water 600ml'), findsOneWidget);
    });

    testWidgets('tapping a product opens its details', (tester) async {
      when(() => products.get('p2')).thenAnswer((_) async => _tea);
      await pumpSignedIn(tester);

      await tester.tap(find.text('Green tea 500ml'));
      await tester.pumpAndSettle();

      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('BEV-002'), findsOneWidget);
      expect(find.text('No confirmed movements yet'), findsOneWidget);
    });
  });
}
