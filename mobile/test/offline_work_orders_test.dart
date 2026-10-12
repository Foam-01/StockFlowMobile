import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stockflow/core/errors.dart';
import 'package:stockflow/features/offline/data/local_store.dart';
import 'package:stockflow/features/work_orders/data/offline_work_orders_repository.dart';
import 'package:stockflow/features/work_orders/data/work_order_offline_store.dart';

import 'fakes.dart';

void main() {
  late MemoryWoOfflineStore store;
  late FakeServer server;
  late OfflineWorkOrdersRepository repo;

  setUp(() async {
    store = MemoryWoOfflineStore();
    server = FakeServer(store);
    repo = OfflineWorkOrdersRepository(server, store);
    await repo.get('wo1'); // opened once while online
  });

  test(
    'a job opened before is shown from the saved copy when offline',
    () async {
      server.offline = true;
      final wo = await repo.get('wo1');
      expect(wo.cachedAt, isNotNull);
      expect(wo.checklist, hasLength(2));
    },
  );

  test('never-opened jobs still fail offline (no invented data)', () async {
    server.offline = true;
    expect(repo.get('other'), throwsA(isA<ApiException>()));
  });

  test(
    'online ticks go straight to the server with the value they were based on',
    () async {
      final wo = await repo.setChecklistItem('wo1', 'item0', done: true);
      expect(wo.checklist[0].done, isTrue);
      expect(wo.hasUnsyncedChecklist, isFalse);
      expect(server.calls.single, {
        'item': 'item0',
        'done': true,
        'expected': false,
      });
    },
  );

  test(
    'offline ticks are queued, shown as pending, and survive a reload',
    () async {
      server.offline = true;
      var wo = await repo.setChecklistItem('wo1', 'item0', done: true);
      expect(wo.checklist[0].done, isTrue);
      expect(wo.localChecklist['item0']?.failed, isFalse);

      wo = await repo.get('wo1'); // e.g. screen reopened
      expect(wo.checklist[0].done, isTrue);
      expect(wo.hasUnsyncedChecklist, isTrue);
      expect(server.done['item0'], isFalse); // server untouched
    },
  );

  test(
    'one queued edit per item: the latest wins, untick-back cancels it',
    () async {
      server.offline = true;
      await repo.setChecklistItem('wo1', 'item0', done: true);
      await repo.setChecklistItem(
        'wo1',
        'item0',
        done: true,
        note: 'gauge 120 psi',
      );
      expect(await store.ops(), hasLength(1));
      expect((await store.ops()).single.note, 'gauge 120 psi');

      await repo.setChecklistItem('wo1', 'item1', done: true);
      await repo.setChecklistItem('wo1', 'item1', done: false);
      expect((await store.ops()).map((o) => o.itemId), ['item0']);
    },
  );

  test('sync sends queued edits once and clears them', () async {
    server.offline = true;
    await repo.setChecklistItem('wo1', 'item0', done: true, note: 'ok');
    server.offline = false;

    final r = await syncChecklistOps(store, server);
    expect(r, (synced: 1, failed: 0, stoppedOffline: false));
    expect(server.done['item0'], isTrue);
    expect(server.notes['item0'], 'ok');
    expect(server.calls.single['expected'], isFalse);
    expect(await store.ops(), isEmpty);
    expect((await repo.get('wo1')).hasUnsyncedChecklist, isFalse);
  });

  test('sync stops while offline and keeps the edit for later', () async {
    server.offline = true;
    await repo.setChecklistItem('wo1', 'item0', done: true);
    final r = await syncChecklistOps(store, server);
    expect(r.stoppedOffline, isTrue);
    expect((await store.ops()).single.attempts, 1);
    expect((await store.ops()).single.failed, isFalse);
  });

  test('a stale edit is refused, kept with the reason, and can be discarded', () async {
    server.offline = true;
    await repo.setChecklistItem(
      'wo1',
      'item0',
      done: true,
    ); // based on "not done"
    // Meanwhile someone else ticked and unticked… then marked it done elsewhere
    // and this device's later "untick" is based on the old value.
    await repo.setChecklistItem('wo1', 'item1', done: true);
    server.done['item1'] = true; // the server already has item1 done…
    await store.putOp(
      (await store.ops())
          .firstWhere((o) => o.itemId == 'item1')
          .copyWith(done: false), // …and this device now wants it undone
    );
    server.offline = false;

    final r = await syncChecklistOps(store, server);
    expect(r.synced, 1);
    expect(r.failed, 1);
    var wo = await repo.get('wo1');
    expect(
      wo.localChecklist['item1']?.error,
      contains('changed on the server'),
    );
    expect(server.done['item1'], isTrue); // newer server value kept

    // A failed edit is not retried on its own.
    expect((await syncChecklistOps(store, server)).synced, 0);

    wo = await repo.discardLocalEdit('wo1', 'item1');
    expect(wo.hasUnsyncedChecklist, isFalse);
    expect(wo.checklist[1].done, isTrue);
  });

  group('SQLite', () {
    setUpAll(sqfliteFfiInit);

    test('stores saved jobs and queued edits', () async {
      databaseFactory = databaseFactoryFfi;
      final db = await openLocalDatabase(path: inMemoryDatabasePath);
      final s = SqliteWoOfflineStore(db);
      await s.cache({'id': 'wo1', 'x': 1});
      expect((await s.cached('wo1'))!.json['x'], 1);
      final op = ChecklistOp(
        woId: 'wo1',
        itemId: 'i1',
        done: true,
        note: null,
        hasNote: true,
        expectedDone: false,
        createdAt: DateTime(2026, 10, 12),
      );
      await s.putOp(op);
      await s.putOp(op.copyWith(done: false)); // same item: replaced
      final ops = await s.ops(woId: 'wo1');
      expect(ops, hasLength(1));
      expect(ops.single.done, isFalse);
      expect(ops.single.hasNote, isTrue);
      await s.removeOp('wo1', 'i1');
      expect(await s.ops(), isEmpty);
      await db.close();
    });

    test(
      'a v1 database (stock queue only) upgrades without losing data',
      () async {
        databaseFactory = databaseFactoryFfi;
        final dir = await Directory.systemTemp.createTemp('sf_db');
        final path = '${dir.path}/upgrade.db';
        final v1 = await openDatabase(
          path,
          version: 1,
          onCreate: (db, _) => db.execute(
            'CREATE TABLE outbox (client_uuid TEXT PRIMARY KEY, type TEXT NOT NULL,'
            ' lines TEXT NOT NULL, reference_no TEXT, note TEXT,'
            ' created_at INTEGER NOT NULL, status TEXT NOT NULL, error TEXT,'
            ' attempts INTEGER NOT NULL DEFAULT 0)',
          ),
        );
        await v1.insert('outbox', {
          'client_uuid': 'keep-me',
          'type': 'RECEIVE',
          'lines': '[]',
          'created_at': 1,
          'status': 'pending',
        });
        await v1.close();

        final v2 = await openLocalDatabase(path: path);
        expect(await v2.query('outbox'), hasLength(1));
        await SqliteWoOfflineStore(v2).cache({'id': 'wo1'});
        expect(await v2.query('wo_cache'), hasLength(1));
        await v2.close();
        await dir.delete(recursive: true);
      },
    );
  });
}
