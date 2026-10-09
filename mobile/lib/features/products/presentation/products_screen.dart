import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/product.dart';
import 'products_controller.dart';
import 'widgets/stock_badge.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(productFilterProvider).query;
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        ref.read(productListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // update clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(productFilterProvider.notifier).setQuery(value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    ref.read(productFilterProvider.notifier).setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(productListProvider);
    final filter = ref.watch(productFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  key: const Key('product_search'),
                  controller: _search,
                  hintText: 'Search name, SKU or barcode',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: _onSearchChanged,
                  trailing: [
                    if (_search.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: _clearSearch,
                      ),
                  ],
                ),
              ),
              _FilterBar(filter: filter),
            ],
          ),
        ),
      ),
      body: switch (list) {
        AsyncValue(:final value?, isLoading: false) ||
        AsyncValue(:final value?, hasError: false) => _buildList(value, filter),
        AsyncValue(:final error?, isLoading: false) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(productListProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildList(ProductListState state, ProductFilter filter) {
    final notifier = ref.read(productListProvider.notifier);
    final isFiltered =
        filter.query.isNotEmpty || filter.categoryId != null || filter.lowStock;

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            isFiltered
                ? MessageView(
                    icon: Icons.search_off,
                    title: 'No matching products',
                    message: 'Try a different search or clear the filters.',
                    action: OutlinedButton(
                      onPressed: () {
                        _clearSearch();
                        ref.invalidate(productFilterProvider);
                      },
                      child: const Text('Clear filters'),
                    ),
                  )
                : const MessageView(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products yet',
                    message: 'Products added by an admin will appear here.',
                  ),
          ],
        ),
      );
    }

    final showFooter = state.hasMore || state.loadMoreError != null;
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: state.items.length + 1 + (showFooter ? 1 : 0),
        separatorBuilder: (_, i) =>
            i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${state.total} product${state.total == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final index = i - 1;
          if (index < state.items.length) {
            return _ProductTile(product: state.items[index]);
          }
          return _ListFooter(state: state, onRetry: notifier.loadMore);
        },
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});

  final ProductFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final notifier = ref.read(productFilterProvider.notifier);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            key: const Key('filter_low_stock'),
            avatar: const Icon(Icons.warning_amber_rounded, size: 18),
            label: const Text('Low stock'),
            selected: filter.lowStock,
            onSelected: (_) => notifier.toggleLowStock(),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('All'),
            selected: filter.categoryId == null,
            onSelected: (_) => notifier.setCategory(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(c.name),
              selected: filter.categoryId == c.id,
              onSelected: (_) => notifier.setCategory(c.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          product.name.characters.first.toUpperCase(),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [product.sku, ?product.category?.name].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: StockBadge(product: product),
      onTap: () => context.push('/products/${product.id}'),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state, required this.onRetry});

  final ProductListState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(ApiException.from(state.loadMoreError!).message),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
