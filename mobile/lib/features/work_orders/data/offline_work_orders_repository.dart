import 'dart:convert';
import 'dart:typed_data';

import '../../../core/errors.dart';
import '../../products/domain/product.dart';
import '../domain/work_order.dart';
import 'work_order_offline_store.dart';
import 'work_orders_repository.dart';

/// Adds the offline part of field work on top of the API:
///
/// - a job opened before can be viewed without a connection (saved copy,
///   marked with [WorkOrder.cachedAt]);
/// - ticking checklist items and editing their notes works offline: the
///   change is queued per item and sent later with the value it was based
///   on, so the server can refuse it if the item changed meanwhile.
///
/// Everything else (start, photos, submit, review, assignment) stays online
/// only: those are server decisions.
class OfflineWorkOrdersRepository implements WorkOrdersRepository {
  OfflineWorkOrdersRepository(this._api, this._store);

  final WorkOrdersRepository _api;
  final WoOfflineStore _store;

  /// Server JSON with this device's unsynced checklist edits applied.
  Future<WorkOrder> _overlay(
    Map<String, dynamic> serverJson, {
    DateTime? cachedAt,
  }) async {
    final id = serverJson['id'] as String;
    final ops = await _store.ops(woId: id);
    if (ops.isEmpty && cachedAt == null) return WorkOrder.fromJson(serverJson);
    final json =
        jsonDecode(jsonEncode(serverJson)) as Map<String, dynamic>; // copy
    final byItem = {for (final o in ops) o.itemId: o};
    for (final item in json['checklist'] as List) {
      final op = byItem[(item as Map<String, dynamic>)['id']];
      if (op == null) continue;
      item['done'] = op.done;
      if (op.hasNote) item['note'] = op.note;
    }
    return WorkOrder.fromJson(
      json,
      cachedAt: cachedAt,
      localChecklist: {
        for (final o in ops) o.itemId: LocalEdit(error: o.error),
      },
    );
  }

  @override
  Future<WorkOrder> get(String id) async {
    try {
      final fresh = await _api.get(id);
      final saved = await _store.cached(id);
      // The API saves what it receives; re-read to apply local edits.
      return saved == null ? fresh : await _overlay(saved.json);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final saved = await _store.cached(id);
      if (saved == null) rethrow;
      return _overlay(saved.json, cachedAt: saved.cachedAt);
    }
  }

  @override
  Future<WorkOrder> setChecklistItem(
    String id,
    String itemId, {
    required bool done,
    String? note,
    bool? expectedDone,
  }) async {
    final saved = await _store.cached(id);
    final serverItem = (saved?.json['checklist'] as List?)
        ?.cast<Map<String, dynamic>>()
        .where((i) => i['id'] == itemId)
        .firstOrNull;
    final serverDone = expectedDone ?? serverItem?['done'] as bool?;
    final queued = (await _store.ops(woId: id))
        .where((o) => o.itemId == itemId)
        .firstOrNull;

    // An earlier edit for this item is still waiting: keep the order by
    // updating that edit instead of racing it to the server.
    if (queued != null) {
      return _queue(id, itemId, done, note, queued.expectedDone, queued);
    }
    try {
      final fresh = await _api.setChecklistItem(
        id,
        itemId,
        done: done,
        note: note,
        expectedDone: serverDone,
      );
      final saved = await _store.cached(id);
      return saved == null ? fresh : await _overlay(saved.json);
    } on ApiException catch (e) {
      if (!e.isNetwork || serverDone == null) rethrow;
      return _queue(id, itemId, done, note, serverDone, null);
    }
  }

  Future<WorkOrder> _queue(
    String id,
    String itemId,
    bool done,
    String? note,
    bool expectedDone,
    ChecklistOp? previous,
  ) async {
    final hasNote = note != null || (previous?.hasNote ?? false);
    final op = ChecklistOp(
      woId: id,
      itemId: itemId,
      done: done,
      note: note ?? previous?.note,
      hasNote: hasNote,
      expectedDone: expectedDone,
      createdAt: previous?.createdAt ?? DateTime.now(),
    );
    final saved = (await _store.cached(id))!;
    final serverItem = (saved.json['checklist'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((i) => i['id'] == itemId);
    final backToServer =
        done == serverItem['done'] &&
        (!hasNote || (op.note?.trim() ?? '') == (serverItem['note'] ?? ''));
    // Changed back to what the server has: nothing left to send.
    backToServer ? await _store.removeOp(id, itemId) : await _store.putOp(op);
    return _overlay(saved.json, cachedAt: saved.cachedAt);
  }

  /// Drops this device's edit and shows the server's value again.
  Future<WorkOrder> discardLocalEdit(String id, String itemId) async {
    await _store.removeOp(id, itemId);
    return get(id);
  }

  // ------------------------------------------------- online-only passthrough

  @override
  Future<Paged<WorkOrderSummary>> list({
    Set<WoStatus> statuses = const {},
    String? query,
    int page = 1,
    int limit = 20,
  }) => _api.list(statuses: statuses, query: query, page: page, limit: limit);

  @override
  Future<List<WoEvent>> events(String id) => _api.events(id);

  @override
  Future<WorkOrder> create(NewWorkOrder order) => _api.create(order);

  @override
  Future<WorkOrder> assign(
    String id, {
    String? assigneeId,
    String? reviewerId,
  }) => _api.assign(id, assigneeId: assigneeId, reviewerId: reviewerId);

  @override
  Future<WorkOrder> start(String id) => _api.start(id);

  @override
  Future<WorkOrder> submit(String id) => _api.submit(id);

  @override
  Future<WorkOrder> approve(String id, {String? note}) =>
      _api.approve(id, note: note);

  @override
  Future<WorkOrder> requestChanges(String id, String reason) =>
      _api.requestChanges(id, reason);

  @override
  Future<WorkOrder> cancel(String id, String reason) => _api.cancel(id, reason);

  @override
  Future<WorkOrder> uploadEvidence(
    String id,
    EvidenceCategory category,
    Uint8List bytes,
    String filename, {
    String? note,
    void Function(double progress)? onProgress,
  }) => _api.uploadEvidence(
    id,
    category,
    bytes,
    filename,
    note: note,
    onProgress: onProgress,
  );

  @override
  Future<WorkOrder> removeEvidence(String id, String evidenceId) =>
      _api.removeEvidence(id, evidenceId);

  @override
  Future<List<ChecklistTemplate>> templates() => _api.templates();

  @override
  Future<List<Person>> people(String role) => _api.people(role);
}

/// Sends queued checklist edits, oldest first (same rules as the stock
/// outbox): accepted → removed; no connection / 5xx → stop and keep for
/// later; refused (e.g. 409 changed on the server, job no longer in
/// progress) → kept with the server's message for the user to resolve.
Future<({int synced, int failed, bool stoppedOffline})> syncChecklistOps(
  WoOfflineStore store,
  WorkOrdersRepository api,
) async {
  var synced = 0;
  var failed = 0;
  for (final op in await store.ops()) {
    if (op.failed) continue;
    try {
      await api.setChecklistItem(
        op.woId,
        op.itemId,
        done: op.done,
        note: op.hasNote ? (op.note ?? '') : null,
        expectedDone: op.expectedDone,
      );
      await store.removeOp(op.woId, op.itemId);
      synced++;
    } catch (e) {
      final error = ApiException.from(e);
      if (error.isTransient) {
        await store.putOp(op.copyWith(attempts: op.attempts + 1));
        return (synced: synced, failed: failed, stoppedOffline: true);
      }
      await store.putOp(
        op.copyWith(error: () => error.message, attempts: op.attempts + 1),
      );
      failed++;
    }
  }
  return (synced: synced, failed: failed, stoppedOffline: false);
}
