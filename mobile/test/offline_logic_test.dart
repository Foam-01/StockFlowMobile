import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockflow/core/errors.dart';
import 'package:stockflow/features/offline/data/local_store.dart';
import 'package:stockflow/features/offline/domain/pending_op.dart';
import 'package:stockflow/features/offline/domain/sync_engine.dart';
import 'package:stockflow/features/operations/domain/stock_transaction.dart';
import 'package:stockflow/features/products/data/cached_products_repository.dart';
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';

class MockProducts extends Mock implements ProductsRepository {}

PendingOp _op(String id, {int minute = 0}) => PendingOp(
  clientUuid: id,
  type: TxType.receive,
  createdAt: DateTime(2026, 10, 10, 9, minute),
  referenceNo: 'REF-$id',
  lines: const [
    PendingLine(
      productId: 'p1',
      productName: 'Water',
      sku: 'BEV-001',
      unit: 'bottle',
      quantity: 3,
    ),
  ],
);

const _water = Product(
  id: 'p1',
  sku: 'BEV-001',
  barcode: '8850999320014',
  name: 'Drinking water 600ml',
  unit: 'bottle',
  minStock: 24,
  onHand: 10,
  category: Category(id: 'c1', name: 'Beverages'),
);
const _chips = Product(
  id: 'p2',
  sku: 'SNK-001',
  barcode: '8850718801015',
  name: 'Potato chips',
  unit: 'bag',
  minStock: 5,
  onHand: 50,
  category: Category(id: 'c2', name: 'Snacks'),
);

final _offline = ApiException('offline', isNetwork: true);

void main() {
  group('SyncEngine', () {
    late MemoryOutbox outbox;
    setUp(() async {
      outbox = MemoryOutbox();
      for (final (i, id) in ['a', 'b', 'c'].indexed) {
        await outbox.put(_op(id, minute: i));
      }
    });

    test('sends oldest first and removes what succeeded', () async {
      final sent = <String>[];
      final report = await SyncEngine(
        outbox,
        (op) async => sent.add(op.clientUuid),
      ).syncAll();

      expect(sent, ['a', 'b', 'c']);
      expect(report.synced, 3);
      expect(await outbox.all(), isEmpty);
    });

    test('stops on a network error and keeps the rest pending', () async {
      final report = await SyncEngine(outbox, (op) async {
        if (op.clientUuid == 'b') throw _offline;
      }).syncAll();

      expect(report.synced, 1);
      expect(report.stoppedOffline, isTrue);
      final left = await outbox.all();
      expect(left.map((o) => o.clientUuid), ['b', 'c']);
      expect(left.every((o) => o.status == PendingStatus.pending), isTrue);
      expect(left.first.attempts, 1);
    });

    test('treats 5xx as temporary', () async {
      final report = await SyncEngine(outbox, (op) async {
        throw ApiException('down', statusCode: 503);
      }).syncAll();
      expect(report.stoppedOffline, isTrue);
      expect((await outbox.all()).length, 3);
    });

    test('marks a rejected item failed and continues with the rest', () async {
      final report = await SyncEngine(outbox, (op) async {
        if (op.clientUuid == 'a') {
          throw ApiException(
            'One or more products do not exist',
            statusCode: 400,
          );
        }
      }).syncAll();

      expect(report.synced, 2);
      expect(report.failed, 1);
      final left = await outbox.all();
      expect(left.single.clientUuid, 'a');
      expect(left.single.status, PendingStatus.failed);
      expect(left.single.error, 'One or more products do not exist');
    });

    test('skips failed items on later passes', () async {
      await outbox.put(
        _op('a').copyWith(status: PendingStatus.failed, error: () => 'x'),
      );
      final sent = <String>[];
      await SyncEngine(outbox, (op) async => sent.add(op.clientUuid)).syncAll();
      expect(sent, ['b', 'c']);
    });
  });

  group('SQLite stores', () {
    late Database db;

    setUpAll(sqfliteFfiInit);
    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await openLocalDatabase(path: inMemoryDatabasePath);
    });
    tearDown(() => db.close());

    test('outbox round-trips documents in order', () async {
      final outbox = SqliteOutbox(db);
      await outbox.put(_op('later', minute: 5));
      await outbox.put(_op('first', minute: 1));
      await outbox.put(
        _op('first', minute: 1).copyWith(
          status: PendingStatus.failed,
          error: () => 'rejected',
          attempts: 2,
        ),
      ); // replace, not duplicate

      final all = await outbox.all();
      expect(all.map((o) => o.clientUuid), ['first', 'later']);
      expect(all.first.status, PendingStatus.failed);
      expect(all.first.error, 'rejected');
      expect(all.first.attempts, 2);
      expect(all.first.lines.single.productName, 'Water');
      expect(all.first.type, TxType.receive);

      await outbox.remove('first');
      expect((await outbox.all()).single.clientUuid, 'later');
    });

    test('product cache searches like the API', () async {
      final cache = SqliteProductCache(db);
      await cache.putAll([_water, _chips]);
      await cache.putAll([_water]); // upsert

      expect((await cache.search()).map((p) => p.sku), ['BEV-001', 'SNK-001']);
      expect((await cache.search(query: 'chip')).single.id, 'p2');
      expect((await cache.search(query: '885099')).single.id, 'p1');
      expect((await cache.search(categoryId: 'c1')).single.id, 'p1');
      expect((await cache.search(lowStock: true)).single.id, 'p1');
      expect((await cache.byBarcode('8850718801015'))!.name, 'Potato chips');
      expect((await cache.byId('p1'))!.category!.name, 'Beverages');
      expect(await cache.byBarcode('nope'), isNull);
    });
  });

  group('CachedProductsRepository', () {
    late MockProducts api;
    late MemoryProductCache cache;
    late CachedProductsRepository repo;

    setUp(() {
      api = MockProducts();
      cache = MemoryProductCache();
      repo = CachedProductsRepository(api, cache);
    });

    void listReturns(Future<Paged<Product>> Function() f) => when(
      () => api.list(
        query: any(named: 'query'),
        categoryId: any(named: 'categoryId'),
        lowStock: any(named: 'lowStock'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => f());

    test('caches online results and serves them offline', () async {
      listReturns(
        () async => const Paged(items: [_water, _chips], total: 2, page: 1),
      );
      await repo.list();

      listReturns(() async => throw _offline);
      final offline = await repo.list(query: 'water');
      expect(offline.items.single.id, 'p1');

      when(() => api.getByBarcode(any())).thenThrow(_offline);
      expect((await repo.getByBarcode('8850718801015')).id, 'p2');

      when(() => api.categories()).thenThrow(_offline);
      expect((await repo.categories()).map((c) => c.name), [
        'Beverages',
        'Snacks',
      ]);
    });

    test('offline with an empty cache still reports the error', () async {
      listReturns(() async => throw _offline);
      expect(repo.list(), throwsA(isA<ApiException>()));
    });

    test('server errors are not hidden by the cache', () async {
      await cache.putAll([_water]);
      when(() => api.getByBarcode('0000'))
          .thenThrow(ApiException('Not found', statusCode: 404));
      expect(repo.getByBarcode('0000'), throwsA(isA<ApiException>()));
    });
  });
}
