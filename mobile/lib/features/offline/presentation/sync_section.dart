import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../operations/presentation/widgets/tx_widgets.dart';
import '../domain/pending_op.dart';
import 'sync_controller.dart';
import '../../../core/l10n.dart';

/// Offline banner + documents waiting to sync, shown above the operations
/// list. Renders nothing when online with an empty queue.
class SyncSection extends ConsumerWidget {
  const SyncSection({super.key});

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final report = await ref.read(syncControllerProvider.notifier).syncNow();
    if (report == null) return;
    final parts = [
      if (report.synced > 0) t.syncedCount(report.synced),
      if (report.failed > 0) t.needAttentionCount(report.failed),
      if (report.stoppedOffline) t.serverRetryLater,
    ];
    // Replace any earlier sync message rather than queueing behind it.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(parts.isEmpty ? t.nothingToSync : parts.join(' · ')),
        ),
      );
  }

  Future<void> _showFailed(
    BuildContext context,
    WidgetRef ref,
    PendingOp op,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.couldNotSync),
        content: Text(
          '${op.error ?? context.l10n.serverRejected}\n\n'
          '${context.l10n.retryOrDiscard}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(context.l10n.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'retry'),
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
    final notifier = ref.read(syncControllerProvider.notifier);
    if (action == 'retry') await notifier.retry(op.clientUuid);
    if (action == 'discard') await notifier.discard(op.clientUuid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider).value;
    final online = ref.watch(connectivityProvider).value ?? true;
    final queue = state?.queue ?? const [];
    if (online && queue.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final syncing = state?.syncing ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!online)
          Container(
            key: const Key('offline_banner'),
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.cloud_off, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.offlineBanner,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (queue.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.waitingToSync(queue.length),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  key: const Key('sync_now'),
                  onPressed: syncing ? null : () => _sync(context, ref),
                  icon: syncing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: Text(
                    syncing ? context.l10n.syncing : context.l10n.syncNow,
                  ),
                ),
              ],
            ),
          ),
          for (final op in queue)
            _PendingTile(
              op: op,
              onTap: op.status == PendingStatus.failed
                  ? () => _showFailed(context, ref, op)
                  : null,
            ),
          const Divider(height: 16),
        ],
      ],
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.op, this.onTap});

  final PendingOp op;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = op.status == PendingStatus.failed;
    final first = op.lines.first;
    final summary = op.lines.length == 1
        ? first.productName
        : context.l10n.moreCount(first.productName, op.lines.length - 1);

    return ListTile(
      key: Key('pending_${op.clientUuid}'),
      dense: true,
      leading: TxTypeIcon(type: op.type),
      title: Text(
        op.referenceNo?.isNotEmpty == true
            ? op.referenceNo!
            : op.type.tr(context.l10n),
      ),
      subtitle: Text(
        failed ? (op.error ?? context.l10n.rejectedByServer) : summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: failed ? TextStyle(color: scheme.error) : null,
      ),
      trailing: failed
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: scheme.error, size: 18),
                const SizedBox(width: 4),
                Text(
                  context.l10n.failed,
                  style: TextStyle(color: scheme.error),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(context.l10n.pending),
              ],
            ),
      onTap: onTap,
    );
  }
}
