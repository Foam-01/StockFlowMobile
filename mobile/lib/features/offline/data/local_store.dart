import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../products/domain/product.dart';
import '../domain/pending_op.dart';

/// Opened in main() on mobile; null on web (in-memory stores are used).
final localDatabaseProvider = Provider<Database?>((_) => null);

Future<Database> openLocalDatabase({String? path}) async => openDatabase(
  path ?? p.join(await getDatabasesPath(), 'stockflow.db'),
  version: 1,
  onCreate: (db, _) async {
    await db.execute('''
      CREATE TABLE outbox (
        client_uuid  TEXT PRIMARY KEY,
        type         TEXT NOT NULL,
        lines        TEXT NOT NULL,
        reference_no TEXT,
        note         TEXT,
        created_at   INTEGER NOT NULL,
        status       TEXT NOT NULL,
        error        TEXT,
        attempts     INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE product_cache (
        id       TEXT PRIMARY KEY,
        sku      TEXT NOT NULL,
        barcode  TEXT,
        name     TEXT NOT NULL,
        json     TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX product_cache_barcode ON product_cache(barcode)',
    );
  },
);

// ---------------------------------------------------------------- outbox

/// Documents waiting to be sent, oldest first.
abstract class Outbox {
  Future<List<PendingOp>> all();
  Future<void> put(PendingOp op);
  Future<void> remove(String clientUuid);
}

final outboxProvider = Provider<Outbox>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return db == null ? MemoryOutbox() : SqliteOutbox(db);
});

class SqliteOutbox implements Outbox {
  SqliteOutbox(this._db);

  final Database _db;

  @override
  Future<List<PendingOp>> all() async => [
    for (final r in await _db.query('outbox', orderBy: 'created_at'))
      PendingOp.fromRow(r),
  ];

  @override
  Future<void> put(PendingOp op) => _db.insert(
    'outbox',
    op.toRow(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  @override
  Future<void> remove(String clientUuid) =>
      _db.delete('outbox', where: 'client_uuid = ?', whereArgs: [clientUuid]);
}

class MemoryOutbox implements Outbox {
  final _ops = <String, PendingOp>{};

  @override
  Future<List<PendingOp>> all() async =>
      _ops.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<void> put(PendingOp op) async => _ops[op.clientUuid] = op;

  @override
  Future<void> remove(String clientUuid) async => _ops.remove(clientUuid);
}

// --------------------------------------------------------- product cache

/// Last-known products, so search, the picker and scanning work offline.
abstract class ProductCache {
  Future<void> putAll(List<Product> products);
  Future<List<Product>> search({
    String? query,
    String? categoryId,
    bool lowStock = false,
  });
  Future<Product?> byId(String id);
  Future<Product?> byBarcode(String barcode);
}

final productCacheProvider = Provider<ProductCache>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return db == null ? MemoryProductCache() : SqliteProductCache(db);
});

/// Shared filter so both caches behave the same as the API.
bool matchesFilter(
  Product p, {
  String? query,
  String? categoryId,
  bool lowStock = false,
}) {
  if (categoryId != null && p.category?.id != categoryId) return false;
  if (lowStock && p.onHand > p.minStock) return false;
  final q = query?.trim().toLowerCase() ?? '';
  if (q.isEmpty) return true;
  return p.name.toLowerCase().contains(q) ||
      p.sku.toLowerCase().contains(q) ||
      (p.barcode?.contains(q) ?? false);
}

class SqliteProductCache implements ProductCache {
  SqliteProductCache(this._db);

  final Database _db;

  @override
  Future<void> putAll(List<Product> products) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final p in products) {
      batch.insert('product_cache', {
        'id': p.id,
        'sku': p.sku,
        'barcode': p.barcode,
        'name': p.name,
        'json': jsonEncode(p.toJson()),
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Product _decode(Map<String, Object?> r) => Product.fromJson(
    jsonDecode(r['json']! as String) as Map<String, dynamic>,
  );

  @override
  Future<List<Product>> search({
    String? query,
    String? categoryId,
    bool lowStock = false,
  }) async {
    final rows = await _db.query(
      'product_cache',
      orderBy: 'name COLLATE NOCASE',
    );
    return [
      for (final r in rows)
        if (matchesFilter(
          _decode(r),
          query: query,
          categoryId: categoryId,
          lowStock: lowStock,
        ))
          _decode(r),
    ];
  }

  @override
  Future<Product?> byId(String id) async {
    final rows = await _db.query(
      'product_cache',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<Product?> byBarcode(String barcode) async {
    final rows = await _db.query(
      'product_cache',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }
}

class MemoryProductCache implements ProductCache {
  final _byId = <String, Product>{};

  @override
  Future<void> putAll(List<Product> products) async {
    for (final p in products) {
      _byId[p.id] = p;
    }
  }

  @override
  Future<List<Product>> search({
    String? query,
    String? categoryId,
    bool lowStock = false,
  }) async =>
      _byId.values
          .where(
            (p) => matchesFilter(
              p,
              query: query,
              categoryId: categoryId,
              lowStock: lowStock,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<Product?> byId(String id) async => _byId[id];

  @override
  Future<Product?> byBarcode(String barcode) async =>
      _byId.values.where((p) => p.barcode == barcode).firstOrNull;
}
