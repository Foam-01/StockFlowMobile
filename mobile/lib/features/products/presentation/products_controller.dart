import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/products_repository.dart';
import '../domain/product.dart';

class ProductFilter {
  const ProductFilter({
    this.query = '',
    this.categoryId,
    this.lowStock = false,
  });

  final String query;
  final String? categoryId;
  final bool lowStock;

  ProductFilter copyWith({
    String? query,
    String? Function()? categoryId,
    bool? lowStock,
  }) => ProductFilter(
    query: query ?? this.query,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    lowStock: lowStock ?? this.lowStock,
  );
}

final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(
      ProductFilterNotifier.new,
    );

class ProductFilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  void setQuery(String q) => state = state.copyWith(query: q.trim());
  void setCategory(String? id) => state = state.copyWith(categoryId: () => id);
  void toggleLowStock() => state = state.copyWith(lowStock: !state.lowStock);
}

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(productsRepositoryProvider).categories(),
);

final productDetailProvider = FutureProvider.autoDispose
    .family<Product, String>(
      (ref, id) => ref.watch(productsRepositoryProvider).get(id),
    );

/// Loaded pages of products for the current filter.
class ProductListState {
  const ProductListState({
    required this.items,
    required this.total,
    required this.page,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Product> items;
  final int total;
  final int page;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => items.length < total;

  ProductListState copyWith({
    List<Product>? items,
    int? page,
    bool? loadingMore,
    Object? Function()? loadMoreError,
  }) => ProductListState(
    items: items ?? this.items,
    total: total,
    page: page ?? this.page,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

final productListProvider =
    AsyncNotifierProvider<ProductListController, ProductListState>(
      ProductListController.new,
    );

class ProductListController extends AsyncNotifier<ProductListState> {
  static const pageSize = 20;

  ProductsRepository get _repo => ref.read(productsRepositoryProvider);

  /// Re-runs (back to page 1) whenever the filter changes.
  @override
  Future<ProductListState> build() async {
    final filter = ref.watch(productFilterProvider);
    final page = await _fetch(filter, 1);
    return ProductListState(items: page.items, total: page.total, page: 1);
  }

  Future<Paged<Product>> _fetch(ProductFilter f, int page) => _repo.list(
    query: f.query,
    categoryId: f.categoryId,
    lowStock: f.lowStock,
    page: page,
    limit: pageSize,
  );

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreError: () => null),
    );
    final filter = ref.read(productFilterProvider);
    try {
      final next = await _fetch(filter, current.page + 1);
      // Ignore if the filter changed while loading.
      if (ref.read(productFilterProvider) != filter) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          page: next.page,
          loadingMore: false,
        ),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: () => e),
      );
    }
  }
}
