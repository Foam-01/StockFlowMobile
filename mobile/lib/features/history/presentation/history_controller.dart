import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_repository.dart';
import '../domain/movement.dart';

/// Latest few movements, shown on the product detail screen.
final recentMovementsProvider = FutureProvider.autoDispose
    .family<MovementPage, String>(
      (ref, productId) =>
          ref.watch(historyRepositoryProvider).movements(productId, limit: 5),
    );

class HistoryState {
  const HistoryState({
    required this.items,
    required this.total,
    required this.page,
    required this.unit,
    required this.onHand,
    this.loadingMore = false,
  });

  final List<Movement> items;
  final int total;
  final int page;
  final String unit;
  final int onHand;
  final bool loadingMore;

  bool get hasMore => items.length < total;

  HistoryState copyWith({
    List<Movement>? items,
    int? page,
    bool? loadingMore,
  }) => HistoryState(
    items: items ?? this.items,
    total: total,
    page: page ?? this.page,
    unit: unit,
    onHand: onHand,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Full, paged movement history for one product.
final productHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<ProductHistoryController, HistoryState, String>(
      ProductHistoryController.new,
    );

class ProductHistoryController extends AsyncNotifier<HistoryState> {
  ProductHistoryController(this.productId);

  final String productId;
  static const pageSize = 20;

  HistoryRepository get _repo => ref.read(historyRepositoryProvider);

  @override
  Future<HistoryState> build() async {
    final p = await _repo.movements(productId, limit: pageSize);
    return HistoryState(
      items: p.items,
      total: p.total,
      page: 1,
      unit: p.unit,
      onHand: p.onHand,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.loadingMore || !s.hasMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final next = await _repo.movements(
        productId,
        page: s.page + 1,
        limit: pageSize,
      );
      state = AsyncData(
        s.copyWith(
          items: [...s.items, ...next.items],
          page: next.page,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(s); // scrolling again retries
    }
  }
}
