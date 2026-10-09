import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../operations/domain/stock_transaction.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/widgets/tx_widgets.dart';
import '../../products/presentation/products_controller.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard.dart';
import 'flow_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            if (user != null)
              Text(
                'Hello, ${user.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: switch (summary) {
        AsyncValue(:final value?, isLoading: false) ||
        AsyncValue(:final value?, hasError: false) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardProvider.future),
          child: _Content(summary: value),
        ),
        AsyncValue(:final error?, isLoading: false) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.summary});

  final DashboardSummary summary;

  void _openLowStock(BuildContext context, WidgetRef ref) {
    final filter = ref.read(productFilterProvider);
    if (!filter.lowStock) {
      ref.read(productFilterProvider.notifier).toggleLowStock();
    }
    context.go('/products');
  }

  void _openDrafts(BuildContext context, WidgetRef ref) {
    ref.read(txStatusFilterProvider.notifier).set(TxStatus.draft);
    context.go('/operations');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = summary.totals;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _TileGrid(
          tiles: [
            _StatTile(
              key: const Key('tile_products'),
              label: 'Products',
              value: t.products,
              onTap: () => context.go('/products'),
            ),
            _StatTile(label: 'Units on hand', value: t.unitsOnHand),
            _StatTile(
              key: const Key('tile_low'),
              label: 'Low stock',
              value: t.lowStock,
              icon: Icons.warning_amber_rounded,
              accent: t.lowStock > 0 ? scheme.tertiary : null,
              onTap: () => _openLowStock(context, ref),
            ),
            _StatTile(
              key: const Key('tile_out'),
              label: 'Out of stock',
              value: t.outOfStock,
              icon: Icons.remove_shopping_cart_outlined,
              accent: t.outOfStock > 0 ? scheme.error : null,
              onTap: () => _openLowStock(context, ref),
            ),
          ],
        ),
        if (t.pendingDrafts > 0) ...[
          const SizedBox(height: 12),
          Card.filled(
            color: scheme.tertiaryContainer,
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const Key('pending_drafts'),
              leading: Icon(
                Icons.pending_actions,
                color: scheme.onTertiaryContainer,
              ),
              title: Text(
                '${t.pendingDrafts} draft${t.pendingDrafts == 1 ? '' : 's'} '
                'waiting for confirmation',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: scheme.onTertiaryContainer,
              ),
              onTap: () => _openDrafts(context, ref),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Section(
          title: 'Last 7 days',
          subtitle:
              '${summary.weekReceived} received · ${summary.weekIssued} issued',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            child: FlowChart(flow: summary.flow),
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Needs attention',
          child: summary.needsAttention.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'All products are above their minimum stock',
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    for (final p in summary.needsAttention)
                      _AttentionTile(item: p),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Recent activity',
          child: summary.recentActivity.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No confirmed operations yet',
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    for (final a in summary.recentActivity)
                      ListTile(
                        leading: TxTypeIcon(type: a.type),
                        title: Text(a.referenceNo ?? a.type.label),
                        subtitle: Text(
                          '${formatDateTime(a.confirmedAt)}'
                          '${a.confirmedBy == null ? '' : ' · ${a.confirmedBy}'}',
                        ),
                        trailing: Text(
                          '${a.itemCount} item${a.itemCount == 1 ? '' : 's'}',
                        ),
                        onTap: () => context.push('/operations/${a.id}'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 600 ? 4 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

/// A headline number. Status tiles pair colour with an icon and label.
class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: accent ?? theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent ?? theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        Card.outlined(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.item});

  final AttentionItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label, icon) = item.isOut
        ? (scheme.error, 'Out of stock', Icons.remove_shopping_cart_outlined)
        : (scheme.tertiary, 'Low stock', Icons.warning_amber_rounded);
    return ListTile(
      leading: Icon(icon, color: color, semanticLabel: label),
      title: Text(item.name),
      subtitle: Text('${item.sku} · min ${item.minStock} ${item.unit}'),
      trailing: Text(
        '${item.onHand} ${item.unit}',
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      onTap: () => context.push('/products/${item.id}'),
    );
  }
}
