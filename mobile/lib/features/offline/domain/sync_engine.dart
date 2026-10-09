import '../../../core/errors.dart';
import '../data/local_store.dart';
import 'pending_op.dart';

class SyncReport {
  const SyncReport({
    this.synced = 0,
    this.failed = 0,
    this.stoppedOffline = false,
  });

  final int synced;
  final int failed;

  /// Stopped early because the server couldn't be reached; the rest stays
  /// pending for the next attempt.
  final bool stoppedOffline;
}

/// Sends queued documents oldest-first.
///
/// - Success: removed from the outbox.
/// - Network / 5xx: stop the pass (everything after would fail too) and
///   leave items pending for next time.
/// - Other 4xx (e.g. product deleted, validation): mark that item failed with
///   the server's message and continue with the rest, so one bad item never
///   blocks the queue.
class SyncEngine {
  SyncEngine(this._outbox, this._send);

  final Outbox _outbox;
  final Future<void> Function(PendingOp op) _send;

  Future<SyncReport> syncAll() async {
    var synced = 0;
    var failed = 0;
    for (final op in await _outbox.all()) {
      if (op.status != PendingStatus.pending) continue;
      try {
        await _send(op);
        await _outbox.remove(op.clientUuid);
        synced++;
      } catch (e) {
        final error = ApiException.from(e);
        if (error.isTransient) {
          await _outbox.put(op.copyWith(attempts: op.attempts + 1));
          return SyncReport(
            synced: synced,
            failed: failed,
            stoppedOffline: true,
          );
        }
        await _outbox.put(
          op.copyWith(
            status: PendingStatus.failed,
            error: () => error.message,
            attempts: op.attempts + 1,
          ),
        );
        failed++;
      }
    }
    return SyncReport(synced: synced, failed: failed);
  }
}
