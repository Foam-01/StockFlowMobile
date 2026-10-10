import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../offline/presentation/sync_section.dart';
import '../domain/stock_transaction.dart';
import 'operations_controller.dart';
import 'widgets/tx_widgets.dart';
import '../../../core/l10n.dart';

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({super.key});

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        ref.read(txListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _newOperation() async {
    final type = await showModalBottomSheet<TxType>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in TxType.values)
              ListTile(
                leading: TxTypeIcon(type: t),
                title: Text(t.tr(context.l10n)),
                subtitle: Text(switch (t) {
                  TxType.receive => context.l10n.descReceive,
                  TxType.issue => context.l10n.descIssue,
                  TxType.adjust => context.l10n.descAdjust,
                }),
                onTap: () => Navigator.pop(context, t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (type != null && mounted) {
      context.push('/operations/new?type=${type.api}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(txListProvider);
    final status = ref.watch(txStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.stockOperations),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in <TxStatus?>[null, ...TxStatus.values]) ...[
                  ChoiceChip(
                    label: Text(s?.tr(context.l10n) ?? context.l10n.all),
                    selected: status == s,
                    onSelected: (_) =>
                        ref.read(txStatusFilterProvider.notifier).set(s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new_operation'),
        onPressed: _newOperation,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.newLabel),
      ),
      body: Column(
        children: [
          const SyncSection(),
          Expanded(
            child: switch (list) {
              AsyncValue(:final value?, isLoading: false) ||
              AsyncValue(
                :final value?,
                hasError: false,
              ) => _buildList(value, status),
              AsyncValue(:final error?, isLoading: false) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(txListProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildList(TxListState state, TxStatus? status) {
    final notifier = ref.read(txListProvider.notifier);
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            MessageView(
              icon: Icons.receipt_long_outlined,
              title: status == null
                  ? context.l10n.noOperations
                  : context.l10n.noOperationsStatus(status.tr(context.l10n)),
              message: context.l10n.tapNewHint,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _TxTile(tx: state.items[i]);
        },
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final StockTransaction tx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = tx.items.first;
    final summary = tx.items.length == 1
        ? first.productName
        : context.l10n.moreCount(first.productName, tx.items.length - 1);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: TxTypeIcon(type: tx.type),
      title: Row(
        children: [
          Flexible(
            child: Text(
              tx.referenceNo ?? tx.type.tr(context.l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TxStatusChip(status: tx.status),
        ],
      ),
      subtitle: Text(
        '$summary\n${tx.createdByName} · ${formatDateTime(tx.createdAt)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      isThreeLine: true,
      trailing: tx.items.length == 1
          ? SignedQty(value: tx.signedQuantity(first))
          : Text(context.l10n.itemsCount(tx.items.length)),
      onTap: () => context.push('/operations/${tx.id}'),
    );
  }
}
