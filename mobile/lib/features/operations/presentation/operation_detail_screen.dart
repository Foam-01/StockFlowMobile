import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/stock_transaction.dart';
import 'evidence_photos.dart';
import 'operations_controller.dart';
import 'widgets/tx_widgets.dart';
import '../../../core/l10n.dart';

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
            child: Text(context.l10n.back),
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
      appBar: AppBar(title: Text(context.l10n.operation)),
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
                              title: context.l10n.cancelDraftQ,
                              message: context.l10n.noStockEffect,
                              action: context.l10n.cancelDraft,
                              destructive: true,
                              done: context.l10n.draftCancelled,
                              op: () =>
                                  ref.read(txActionsProvider).cancel(t.id),
                            ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(context.l10n.cancel),
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
                              title: context.l10n.confirmTypeQ(
                                t.type.tr(context.l10n),
                              ),
                              message: context.l10n.confirmStockMsg(
                                t.items.length,
                              ),
                              action: context.l10n.confirm,
                              done: context.l10n.stockUpdated,
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
                      label: Text(context.l10n.confirm),
                    ),
                  ),
                ] else
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(context.l10n.waitingAdmin),
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
                  Text(
                    tx.type.tr(context.l10n),
                    style: theme.textTheme.titleLarge,
                  ),
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
              _Info(context.l10n.createdBy, tx.createdByName),
              _Info(context.l10n.createdAt, formatDateTime(tx.createdAt)),
              if (tx.confirmedByName != null)
                _Info(context.l10n.confirmedBy, tx.confirmedByName!),
              if (tx.confirmedAt != null)
                _Info(
                  context.l10n.confirmedAt,
                  formatDateTime(tx.confirmedAt!),
                ),
              if (tx.note != null) _Info(context.l10n.note, tx.note!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.itemsWithCount(tx.items.length),
          style: theme.textTheme.titleMedium,
        ),
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
