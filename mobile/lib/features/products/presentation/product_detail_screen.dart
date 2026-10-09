import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../history/presentation/history_controller.dart';
import '../../history/presentation/movement_tile.dart';
import '../domain/product.dart';
import 'products_controller.dart';
import 'widgets/stock_badge.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: product.when(
        data: (p) => RefreshIndicator(
          onRefresh: () {
            ref.invalidate(recentMovementsProvider(productId));
            return ref.refresh(productDetailProvider(productId).future);
          },
          child: _Details(product: p),
        ),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(productDetailProvider(productId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    product.category?.name ?? 'Uncategorized',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StockBadge(product: product, large: true),
          ],
        ),
        const SizedBox(height: 24),
        Card.outlined(
          child: Column(
            children: [
              _Row(label: 'SKU', value: product.sku),
              _Row(label: 'Barcode', value: product.barcode ?? '—'),
              _Row(label: 'Unit', value: product.unit),
              _Row(
                label: 'On hand',
                value: '${product.onHand} ${product.unit}',
              ),
              _Row(
                label: 'Minimum stock',
                value: '${product.minStock} ${product.unit}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _RecentMovements(product: product),
      ],
    );
  }
}

class _RecentMovements extends ConsumerWidget {
  const _RecentMovements({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recent = ref.watch(recentMovementsProvider(product.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Recent movements', style: theme.textTheme.titleMedium),
            const Spacer(),
            if ((recent.value?.total ?? 0) > 0)
              TextButton(
                key: const Key('view_history'),
                onPressed: () => context.push(
                  '/products/${product.id}/history',
                  extra: product.name,
                ),
                child: Text('View all (${recent.value!.total})'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card.outlined(
          clipBehavior: Clip.antiAlias,
          child: recent.when(
            data: (page) => page.items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No confirmed movements yet',
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: [
                      for (final m in page.items)
                        MovementTile(movement: m, unit: page.unit),
                    ],
                  ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Could not load movements'),
              trailing: TextButton(
                onPressed: () =>
                    ref.invalidate(recentMovementsProvider(product.id)),
                child: const Text('Retry'),
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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
      trailing: SelectableText(value, style: theme.textTheme.bodyLarge),
    );
  }
}
