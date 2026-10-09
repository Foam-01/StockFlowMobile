import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import 'history_controller.dart';
import 'movement_tile.dart';

class ProductHistoryScreen extends ConsumerStatefulWidget {
  const ProductHistoryScreen({
    super.key,
    required this.productId,
    this.productName,
  });

  final String productId;
  final String? productName;

  @override
  ConsumerState<ProductHistoryScreen> createState() =>
      _ProductHistoryScreenState();
}

class _ProductHistoryScreenState extends ConsumerState<ProductHistoryScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        ref.read(productHistoryProvider(widget.productId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = productHistoryProvider(widget.productId);
    final history = ref.watch(provider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stock history'),
            if (widget.productName != null)
              Text(widget.productName!, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: history.when(
        data: (s) => RefreshIndicator(
          onRefresh: ref.read(provider.notifier).refresh,
          child: s.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    MessageView(
                      icon: Icons.history,
                      title: 'No movements yet',
                      message: 'Confirmed operations will appear here.',
                    ),
                  ],
                )
              : ListView.separated(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: s.items.length + 1 + (s.hasMore ? 1 : 0),
                  separatorBuilder: (_, i) => i == 0
                      ? const SizedBox.shrink()
                      : const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          '${s.total} movement${s.total == 1 ? '' : 's'} · '
                          'on hand ${s.onHand} ${s.unit}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    if (i - 1 < s.items.length) {
                      return MovementTile(
                        movement: s.items[i - 1],
                        unit: s.unit,
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
        ),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(provider)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
