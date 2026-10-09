import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/domain/product.dart';
import '../../history/presentation/history_controller.dart';
import '../../products/data/products_repository.dart';
import '../../products/presentation/products_controller.dart';
import '../data/operations_repository.dart';
import '../domain/stock_transaction.dart';

/// Status filter on the operations list; null = all.
final txStatusFilterProvider = NotifierProvider<TxStatusFilter, TxStatus?>(
  TxStatusFilter.new,
);

class TxStatusFilter extends Notifier<TxStatus?> {
  @override
  TxStatus? build() => null;

  void set(TxStatus? s) => state = s;
}

class TxListState {
  const TxListState({
    required this.items,
    required this.total,
    required this.page,
    this.loadingMore = false,
  });

  final List<StockTransaction> items;
  final int total;
  final int page;
  final bool loadingMore;

  bool get hasMore => items.length < total;
}

final txListProvider = AsyncNotifierProvider<TxListController, TxListState>(
  TxListController.new,
);

class TxListController extends AsyncNotifier<TxListState> {
  static const pageSize = 20;

  OperationsRepository get _repo => ref.read(operationsRepositoryProvider);

  @override
  Future<TxListState> build() async {
    final status = ref.watch(txStatusFilterProvider);
    final page = await _repo.list(status: status, limit: pageSize);
    return TxListState(items: page.items, total: page.total, page: 1);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.loadingMore || !s.hasMore) return;
    final status = ref.read(txStatusFilterProvider);
    state = AsyncData(
      TxListState(
        items: s.items,
        total: s.total,
        page: s.page,
        loadingMore: true,
      ),
    );
    try {
      final next = await _repo.list(
        status: status,
        page: s.page + 1,
        limit: pageSize,
      );
      if (ref.read(txStatusFilterProvider) != status) return;
      state = AsyncData(
        TxListState(
          items: [...s.items, ...next.items],
          total: next.total,
          page: next.page,
        ),
      );
    } catch (_) {
      state = AsyncData(s); // keep what we have; scrolling again retries
    }
  }
}

final txDetailProvider = FutureProvider.autoDispose
    .family<StockTransaction, String>(
      (ref, id) => ref.watch(operationsRepositoryProvider).get(id),
    );

/// Actions that change stock; refresh dependent lists afterwards.
final txActionsProvider = Provider<TxActions>(TxActions.new);

class TxActions {
  TxActions(this._ref);

  final Ref _ref;

  OperationsRepository get _repo => _ref.read(operationsRepositoryProvider);

  Future<StockTransaction> create({
    required String clientUuid,
    required TxType type,
    required List<({String productId, int quantity})> items,
    String? referenceNo,
    String? note,
  }) async {
    final tx = await _repo.create(
      clientUuid: clientUuid,
      type: type,
      items: items,
      referenceNo: referenceNo,
      note: note,
    );
    _ref.invalidate(txListProvider);
    return tx;
  }

  Future<StockTransaction> confirm(String id) =>
      _after(id, _repo.confirm(id), stockChanged: true);

  Future<StockTransaction> cancel(String id) => _after(id, _repo.cancel(id));

  Future<StockTransaction> _after(
    String id,
    Future<StockTransaction> op, {
    bool stockChanged = false,
  }) async {
    final tx = await op;
    _ref.invalidate(txListProvider);
    _ref.invalidate(txDetailProvider(id));
    if (stockChanged) {
      _ref.invalidate(productListProvider);
      _ref.invalidate(productDetailProvider);
      _ref.invalidate(recentMovementsProvider);
      _ref.invalidate(productHistoryProvider);
    }
    return tx;
  }
}

/// Products for the picker sheet, searched independently of the Products tab.
final productPickerProvider = FutureProvider.autoDispose
    .family<List<Product>, String>((ref, query) async {
      final page = await ref
          .watch(productsRepositoryProvider)
          .list(query: query, limit: 50);
      return page.items;
    });
