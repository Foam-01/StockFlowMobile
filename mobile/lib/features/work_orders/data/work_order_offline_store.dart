import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../offline/data/local_store.dart';

/// A checklist change made while offline (or not yet accepted).
///
/// [expectedDone] is what the server had when the user made the change; the
/// server refuses the edit if the item changed since (someone else edited
/// it), so an old queued edit never overwrites newer data.
class ChecklistOp {
  const ChecklistOp({
    required this.woId,
    required this.itemId,
    required this.done,
    required this.expectedDone,
    required this.createdAt,
    this.note,
    this.hasNote = false,
    this.error,
    this.attempts = 0,
  });

  final String woId;
  final String itemId;
  final bool done;

  /// Only sent when [hasNote]; null then means "clear the note".
  final String? note;
  final bool hasNote;
  final bool expectedDone;
  final DateTime createdAt;

  /// Server's refusal message; null while pending.
  final String? error;
  final int attempts;

  bool get failed => error != null;

  ChecklistOp copyWith({
    bool? done,
    String? Function()? note,
    bool? hasNote,
    String? Function()? error,
    int? attempts,
  }) => ChecklistOp(
    woId: woId,
    itemId: itemId,
    done: done ?? this.done,
    expectedDone: expectedDone,
    createdAt: createdAt,
    note: note == null ? this.note : note(),
    hasNote: hasNote ?? this.hasNote,
    error: error == null ? this.error : error(),
    attempts: attempts ?? this.attempts,
  );
}

/// Saved work-order JSON (as the server last sent it) and queued checklist
/// edits. Only data the user could already see is stored; no tokens.
abstract class WoOfflineStore {
  Future<({Map<String, dynamic> json, DateTime cachedAt})?> cached(String id);
  Future<void> cache(Map<String, dynamic> json);
  Future<List<ChecklistOp>> ops({String? woId});
  Future<void> putOp(ChecklistOp op);
  Future<void> removeOp(String woId, String itemId);
}

final woOfflineStoreProvider = Provider<WoOfflineStore>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return db == null ? MemoryWoOfflineStore() : SqliteWoOfflineStore(db);
});

class SqliteWoOfflineStore implements WoOfflineStore {
  SqliteWoOfflineStore(this._db);

  final Database _db;

  @override
  Future<({Map<String, dynamic> json, DateTime cachedAt})?> cached(
    String id,
  ) async {
    final rows = await _db.query('wo_cache', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      json: jsonDecode(r['json']! as String) as Map<String, dynamic>,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(r['cached_at']! as int),
    );
  }

  @override
  Future<void> cache(Map<String, dynamic> json) => _db.insert('wo_cache', {
    'id': json['id'],
    'json': jsonEncode(json),
    'cached_at': DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<ChecklistOp>> ops({String? woId}) async {
    final rows = await _db.query(
      'wo_checklist_ops',
      where: woId == null ? null : 'wo_id = ?',
      whereArgs: woId == null ? null : [woId],
      orderBy: 'created_at',
    );
    return [
      for (final r in rows)
        ChecklistOp(
          woId: r['wo_id']! as String,
          itemId: r['item_id']! as String,
          done: r['done'] == 1,
          note: r['note'] as String?,
          hasNote: r['has_note'] == 1,
          expectedDone: r['expected_done'] == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            r['created_at']! as int,
          ),
          error: r['error'] as String?,
          attempts: r['attempts']! as int,
        ),
    ];
  }

  @override
  Future<void> putOp(ChecklistOp op) => _db.insert('wo_checklist_ops', {
    'wo_id': op.woId,
    'item_id': op.itemId,
    'done': op.done ? 1 : 0,
    'note': op.note,
    'has_note': op.hasNote ? 1 : 0,
    'expected_done': op.expectedDone ? 1 : 0,
    'created_at': op.createdAt.millisecondsSinceEpoch,
    'error': op.error,
    'attempts': op.attempts,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> removeOp(String woId, String itemId) => _db.delete(
    'wo_checklist_ops',
    where: 'wo_id = ? AND item_id = ?',
    whereArgs: [woId, itemId],
  );
}

class MemoryWoOfflineStore implements WoOfflineStore {
  final _cache = <String, (Map<String, dynamic>, DateTime)>{};
  final _ops = <String, ChecklistOp>{};

  @override
  Future<({Map<String, dynamic> json, DateTime cachedAt})?> cached(
    String id,
  ) async {
    final c = _cache[id];
    return c == null ? null : (json: c.$1, cachedAt: c.$2);
  }

  @override
  Future<void> cache(Map<String, dynamic> json) async =>
      _cache[json['id'] as String] = (json, DateTime.now());

  @override
  Future<List<ChecklistOp>> ops({String? woId}) async =>
      _ops.values.where((o) => woId == null || o.woId == woId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<void> putOp(ChecklistOp op) async =>
      _ops['${op.woId}/${op.itemId}'] = op;

  @override
  Future<void> removeOp(String woId, String itemId) async =>
      _ops.remove('$woId/$itemId');
}
