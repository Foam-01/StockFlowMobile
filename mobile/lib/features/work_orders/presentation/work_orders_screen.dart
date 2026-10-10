import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/work_order.dart';
import 'widgets/wo_badges.dart';
import 'work_orders_controller.dart';
import '../../../core/l10n.dart';
import '../../notifications/presentation/notifications_controller.dart';
import '../../notifications/presentation/notifications_screen.dart';

class WorkOrdersScreen extends ConsumerStatefulWidget {
  const WorkOrdersScreen({super.key});

  @override
  ConsumerState<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends ConsumerState<WorkOrdersScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        ref.read(woListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final list = ref.watch(woListProvider);
    final query = ref.watch(woQueryProvider);
    final title = switch (user?.role) {
      Role.technician => context.l10n.myJobs,
      Role.supervisor => context.l10n.reviewsJobs,
      _ => context.l10n.workOrders,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [NotificationBell(), SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  key: const Key('wo_search'),
                  controller: _search,
                  hintText: context.l10n.searchWo,
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 350),
                      () => ref.read(woQueryProvider.notifier).setText(v),
                    );
                  },
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final f in WoFilter.values) ...[
                      ChoiceChip(
                        key: Key('wo_filter_${f.name}'),
                        label: Text(f.tr(context.l10n)),
                        selected: query.filter == f,
                        onSelected: (_) =>
                            ref.read(woQueryProvider.notifier).setFilter(f),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: user?.isAdmin ?? false
          ? FloatingActionButton.extended(
              key: const Key('new_work_order'),
              onPressed: () => context.push('/work-orders/new'),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.newLabel),
            )
          : null,
      body: switch (list) {
        AsyncValue(:final value?, isLoading: false) ||
        AsyncValue(:final value?, hasError: false) => _buildList(value, query),
        AsyncValue(:final error?, isLoading: false) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(woListProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildList(WoListState s, WoQuery q) {
    final notifier = ref.read(woListProvider.notifier);
    if (s.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () {
          ref.invalidate(unreadCountProvider);
          return notifier.refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            MessageView(
              icon: Icons.assignment_outlined,
              title: q.text.isNotEmpty
                  ? context.l10n.noMatchingWo
                  : switch (q.filter) {
                      WoFilter.toReview => context.l10n.nothingToReview,
                      WoFilter.active => context.l10n.noActiveJobs,
                      _ => context.l10n.noWoYet,
                    },
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(unreadCountProvider);
        return notifier.refresh();
      },
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: s.items.length + (s.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= s.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _WoCard(wo: s.items[i]);
        },
      ),
    );
  }
}

class _WoCard extends StatelessWidget {
  const _WoCard({required this.wo});

  final WorkOrderSummary wo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final progress = wo.checklistTotal == 0
        ? null
        : wo.checklistDone / wo.checklistTotal;

    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('wo_${wo.id}'),
        onTap: () => context.push('/work-orders/${wo.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(wo.code, style: muted),
                  const SizedBox(width: 8),
                  WoPriorityBadge(priority: wo.priority),
                  const Spacer(),
                  WoStatusChip(status: wo.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                wo.title,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 15, color: muted?.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      wo.siteName,
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 15,
                    color: muted?.color,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      wo.assignee?.name ?? context.l10n.unassigned,
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  WoDue(dueAt: wo.dueAt, overdue: wo.isOverdue),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${wo.checklistDone}/${wo.checklistTotal}',
                      style: muted,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension on WoFilter {
  String tr(L10n t) => switch (this) {
    WoFilter.active => t.filterActive,
    WoFilter.toReview => t.filterToReview,
    WoFilter.done => t.filterDone,
    WoFilter.all => t.all,
  };
}
