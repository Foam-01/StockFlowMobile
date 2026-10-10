import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../products/domain/product.dart';
import '../data/work_orders_repository.dart';
import '../domain/work_order.dart';

/// Status filter presets shown as chips.
enum WoFilter {
  active('Active', {
    WoStatus.open,
    WoStatus.inProgress,
    WoStatus.needsRevision,
  }),
  toReview('To review', {WoStatus.submitted}),
  done('Done', {WoStatus.approved}),
  all('All', {});

  const WoFilter(this.label, this.statuses);

  final String label;
  final Set<WoStatus> statuses;

  /// Sensible starting view per role.
  static WoFilter defaultFor(Role? role) => switch (role) {
    Role.supervisor => WoFilter.toReview,
    Role.technician => WoFilter.active,
    _ => WoFilter.all,
  };
}

class WoQuery {
  const WoQuery({required this.filter, this.text = ''});

  final WoFilter filter;
  final String text;

  WoQuery copyWith({WoFilter? filter, String? text}) =>
      WoQuery(filter: filter ?? this.filter, text: text ?? this.text);
}

final woQueryProvider = NotifierProvider<WoQueryNotifier, WoQuery>(
  WoQueryNotifier.new,
);

class WoQueryNotifier extends Notifier<WoQuery> {
  @override
  WoQuery build() {
    final role = ref.watch(authControllerProvider.select((a) => a.value?.role));
    return WoQuery(filter: WoFilter.defaultFor(role));
  }

  void setFilter(WoFilter f) => state = state.copyWith(filter: f);
  void setText(String t) => state = state.copyWith(text: t.trim());
}

class WoListState {
  const WoListState({
    required this.items,
    required this.total,
    required this.page,
    this.loadingMore = false,
  });

  final List<WorkOrderSummary> items;
  final int total;
  final int page;
  final bool loadingMore;

  bool get hasMore => items.length < total;
}

final woListProvider = AsyncNotifierProvider<WoListController, WoListState>(
  WoListController.new,
);

class WoListController extends AsyncNotifier<WoListState> {
  static const pageSize = 20;

  WorkOrdersRepository get _repo => ref.read(workOrdersRepositoryProvider);

  @override
  Future<WoListState> build() async {
    final q = ref.watch(woQueryProvider);
    final page = await _fetch(q, 1);
    return WoListState(items: page.items, total: page.total, page: 1);
  }

  Future<Paged<WorkOrderSummary>> _fetch(WoQuery q, int page) => _repo.list(
    statuses: q.filter.statuses,
    query: q.text,
    page: page,
    limit: pageSize,
  );

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.loadingMore || !s.hasMore) return;
    final q = ref.read(woQueryProvider);
    state = AsyncData(
      WoListState(
        items: s.items,
        total: s.total,
        page: s.page,
        loadingMore: true,
      ),
    );
    try {
      final next = await _fetch(q, s.page + 1);
      if (ref.read(woQueryProvider) != q) return;
      state = AsyncData(
        WoListState(
          items: [...s.items, ...next.items],
          total: next.total,
          page: next.page,
        ),
      );
    } catch (_) {
      state = AsyncData(s); // scrolling again retries
    }
  }
}

final woEventsProvider = FutureProvider.autoDispose
    .family<List<WoEvent>, String>(
      (ref, id) => ref.watch(workOrdersRepositoryProvider).events(id),
    );

final checklistTemplatesProvider =
    FutureProvider.autoDispose<List<ChecklistTemplate>>(
      (ref) => ref.watch(workOrdersRepositoryProvider).templates(),
    );

final peopleProvider = FutureProvider.autoDispose.family<List<Person>, String>(
  (ref, role) => ref.watch(workOrdersRepositoryProvider).people(role),
);

/// One work order. Every action replaces the state with the server's answer,
/// so the screen never shows a status the server hasn't accepted.
final woDetailProvider = AsyncNotifierProvider.autoDispose
    .family<WoDetailController, WorkOrder, String>(WoDetailController.new);

class WoDetailController extends AsyncNotifier<WorkOrder> {
  WoDetailController(this.id);

  final String id;

  WorkOrdersRepository get _repo => ref.read(workOrdersRepositoryProvider);

  @override
  Future<WorkOrder> build() => _repo.get(id);

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Runs an action; on success shows the new state and refreshes lists.
  /// Errors are rethrown for the screen to show.
  Future<WorkOrder> _apply(Future<WorkOrder> Function() op) async {
    final wo = await op();
    state = AsyncData(wo);
    ref.invalidate(woListProvider);
    ref.invalidate(woEventsProvider(id));
    return wo;
  }

  Future<WorkOrder> start() => _apply(() => _repo.start(id));
  Future<WorkOrder> submit() => _apply(() => _repo.submit(id));
  Future<WorkOrder> approve({String? note}) =>
      _apply(() => _repo.approve(id, note: note));
  Future<WorkOrder> requestChanges(String reason) =>
      _apply(() => _repo.requestChanges(id, reason));
  Future<WorkOrder> cancel(String reason) =>
      _apply(() => _repo.cancel(id, reason));
  Future<WorkOrder> assign({String? assigneeId, String? reviewerId}) => _apply(
    () => _repo.assign(id, assigneeId: assigneeId, reviewerId: reviewerId),
  );
  Future<WorkOrder> setChecklistItem(
    String itemId,
    bool done, {
    String? note,
  }) =>
      _apply(() => _repo.setChecklistItem(id, itemId, done: done, note: note));
  Future<WorkOrder> uploadEvidence(
    EvidenceCategory category,
    Uint8List bytes,
    String filename, {
    String? note,
    void Function(double)? onProgress,
  }) => _apply(
    () => _repo.uploadEvidence(
      id,
      category,
      bytes,
      filename,
      note: note,
      onProgress: onProgress,
    ),
  );
  Future<WorkOrder> removeEvidence(String evidenceId) =>
      _apply(() => _repo.removeEvidence(id, evidenceId));
}
