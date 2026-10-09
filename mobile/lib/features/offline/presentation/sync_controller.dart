import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/data/dashboard_repository.dart';
import '../../operations/data/operations_repository.dart';
import '../../operations/presentation/operations_controller.dart';
import '../data/local_store.dart';
import '../domain/pending_op.dart';
import '../domain/sync_engine.dart';

/// true when the device has some network. A network doesn't guarantee the
/// API is reachable, so this is only a hint to *try* syncing.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online);
});

class SyncState {
  const SyncState({required this.queue, this.syncing = false, this.lastReport});

  final List<PendingOp> queue;
  final bool syncing;
  final SyncReport? lastReport;

  int get pendingCount =>
      queue.where((o) => o.status == PendingStatus.pending).length;
  int get failedCount =>
      queue.where((o) => o.status == PendingStatus.failed).length;

  SyncState copyWith({
    List<PendingOp>? queue,
    bool? syncing,
    SyncReport? lastReport,
  }) => SyncState(
    queue: queue ?? this.queue,
    syncing: syncing ?? this.syncing,
    lastReport: lastReport ?? this.lastReport,
  );
}

final syncControllerProvider = AsyncNotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends AsyncNotifier<SyncState> {
  Outbox get _outbox => ref.read(outboxProvider);

  @override
  Future<SyncState> build() async {
    // Try again whenever the network comes back…
    ref.listen(connectivityProvider, (prev, next) {
      if (next.value == true && prev?.value != true) syncNow();
    });
    // …and when the app returns to the foreground.
    final lifecycle = AppLifecycleListener(onResume: syncNow);
    ref.onDispose(lifecycle.dispose);

    final queue = await _outbox.all();
    if (queue.any((o) => o.status == PendingStatus.pending)) {
      Future.microtask(syncNow);
    }
    return SyncState(queue: queue);
  }

  Future<void> _reload() async {
    final current = state.value ?? const SyncState(queue: []);
    state = AsyncData(current.copyWith(queue: await _outbox.all()));
  }

  /// Saves a document to send later.
  Future<void> enqueue(PendingOp op) async {
    await _outbox.put(op);
    await _reload();
  }

  Future<SyncReport?> syncNow() async {
    final current = state.value;
    if (current == null || current.syncing) return null;
    state = AsyncData(current.copyWith(syncing: true));

    final ops = ref.read(operationsRepositoryProvider);
    final report = await SyncEngine(_outbox, (op) async {
      await ops.create(
        clientUuid: op.clientUuid,
        type: op.type,
        referenceNo: op.referenceNo,
        note: op.note,
        items: [
          for (final l in op.lines)
            (productId: l.productId, quantity: l.quantity),
        ],
      );
    }).syncAll();

    if (report.synced > 0) {
      ref.invalidate(txListProvider);
      ref.invalidate(dashboardProvider);
    }
    state = AsyncData(
      SyncState(queue: await _outbox.all(), lastReport: report),
    );
    return report;
  }

  /// Puts a failed item back in the queue (e.g. after the cause was fixed).
  Future<void> retry(String clientUuid) async {
    final op = (await _outbox.all()).where((o) => o.clientUuid == clientUuid);
    if (op.isEmpty) return;
    await _outbox.put(
      op.first.copyWith(status: PendingStatus.pending, error: () => null),
    );
    await _reload();
    await syncNow();
  }

  Future<void> discard(String clientUuid) async {
    await _outbox.remove(clientUuid);
    await _reload();
  }
}
