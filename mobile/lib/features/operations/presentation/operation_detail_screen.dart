import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/stock_transaction.dart';
import 'evidence_photos.dart';
import 'operations_controller.dart';
import 'widgets/tx_widgets.dart';

class OperationDetailScreen extends ConsumerStatefulWidget {
  const OperationDetailScreen({super.key, required this.txId});

  final String txId;

  @override
  ConsumerState<OperationDetailScreen> createState() =>
      _OperationDetailScreenState();
}

class _OperationDetailScreenState extends ConsumerState<OperationDetailScreen> {
  bool _busy = false;

  Future<void> _run({
    required String title,
    required String message,
    required String action,
    required Future<void> Function() op,
    required String done,
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiException.from(e).message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = ref.watch(txDetailProvider(widget.txId));
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Operation')),
      body: tx.when(
        data: (tx) => _Body(
          tx: tx,
          canEditPhotos:
              user != null && (user.isAdmin || tx.createdById == user.id),
        ),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(txDetailProvider(widget.txId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: switch (tx.value) {
        final StockTransaction t when t.isDraft && user != null => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (user.isAdmin || t.createdById == user.id)
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('cancel_tx'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              title: 'Cancel this draft?',
                              message: 'It will not affect stock.',
                              action: 'Cancel draft',
                              destructive: true,
                              done: 'Draft cancelled',
                              op: () =>
                                  ref.read(txActionsProvider).cancel(t.id),
                            ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                if (user.isAdmin) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const Key('confirm_tx'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              title: 'Confirm ${t.type.label.toLowerCase()}?',
                              message:
                                  'Stock will be updated for ${t.items.length} '
                                  'product${t.items.length == 1 ? '' : 's'}. '
                                  'This cannot be undone.',
                              action: 'Confirm',
                              done: 'Stock updated',
                              op: () =>
                                  ref.read(txActionsProvider).confirm(t.id),
                            ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Confirm'),
                    ),
                  ),
                ] else
                  const Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text('Waiting for an admin to confirm'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _ => null,
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.tx, required this.canEditPhotos});

  final StockTransaction tx;
  final bool canEditPhotos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            TxTypeIcon(type: tx.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.type.label, style: theme.textTheme.titleLarge),
                  if (tx.referenceNo != null)
                    Text(tx.referenceNo!, style: muted),
                ],
              ),
            ),
            TxStatusChip(status: tx.status),
          ],
        ),
        const SizedBox(height: 16),
        Card.outlined(
          child: Column(
            children: [
              _Info('Created by', tx.createdByName),
              _Info('Created at', formatDateTime(tx.createdAt)),
              if (tx.confirmedByName != null)
                _Info('Confirmed by', tx.confirmedByName!),
              if (tx.confirmedAt != null)
                _Info('Confirmed at', formatDateTime(tx.confirmedAt!)),
              if (tx.note != null) _Info('Note', tx.note!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Items (${tx.items.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card.outlined(
          child: Column(
            children: [
              for (final item in tx.items)
                ListTile(
                  title: Text(item.productName),
                  subtitle: Text(item.sku),
                  trailing: SignedQty(
                    value: tx.signedQuantity(item),
                    unit: item.unit,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EvidencePhotos(tx: tx, canEdit: canEditPhotos),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(value, style: theme.textTheme.bodyLarge),
    );
  }
}
