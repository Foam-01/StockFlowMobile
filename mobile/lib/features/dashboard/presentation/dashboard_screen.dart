import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../operations/domain/stock_transaction.dart';
import '../../operations/presentation/operations_controller.dart';
import '../../operations/presentation/widgets/tx_widgets.dart';
import '../../products/presentation/products_controller.dart';
import '../../scanner/presentation/barcode_lookup.dart';
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
      body: switch (summary) {
        AsyncValue(:final value?, isLoading: false) ||
        AsyncValue(:final value?, hasError: false) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardProvider.future),
          child: _Content(summary: value, userName: user?.name),
        ),
        AsyncValue(:final error?, isLoading: false) => SafeArea(
          child: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.summary, this.userName});

  final DashboardSummary summary;
  final String? userName;

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
      padding: EdgeInsets.zero,
      children: [
        _Header(
          userName: userName,
          totals: t,
          onProducts: () => context.go('/products'),
          onReceive: () => context.push('/operations/new?type=RECEIVE'),
          onIssue: () => context.push('/operations/new?type=ISSUE'),
          onScan: () async {
            final product = await scanProduct(context, ref);
            if (product != null && context.mounted) {
              context.push('/products/${product.id}');
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AlertTile(
                      key: const Key('tile_low'),
                      label: 'Low stock',
                      value: t.lowStock,
                      icon: Icons.trending_down_rounded,
                      color: scheme.tertiary,
                      container: scheme.tertiaryContainer,
                      onTap: () => _openLowStock(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AlertTile(
                      key: const Key('tile_out'),
                      label: 'Out of stock',
                      value: t.outOfStock,
                      icon: Icons.block_rounded,
                      color: scheme.error,
                      container: scheme.errorContainer,
                      onTap: () => _openLowStock(context, ref),
                    ),
                  ),
                ],
              ),
              if (t.pendingDrafts > 0) ...[
                const SizedBox(height: 12),
                Material(
                  color: scheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    key: const Key('pending_drafts'),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.pending_actions_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      '${t.pendingDrafts} draft${t.pendingDrafts == 1 ? '' : 's'} '
                      'waiting for confirmation',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openDrafts(context, ref),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _Section(
                title: 'Last 7 days',
                subtitle:
                    '${summary.weekReceived} received · ${summary.weekIssued} issued',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                  child: FlowChart(flow: summary.flow),
                ),
              ),
              const SizedBox(height: 28),
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
              const SizedBox(height: 28),
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
          ),
        ),
      ],
    );
  }
}

/// Deep green panel: greeting, the one number that sums up the warehouse,
/// and the three things people open the app to do.
class _Header extends StatelessWidget {
  const _Header({
    required this.userName,
    required this.totals,
    required this.onProducts,
    required this.onReceive,
    required this.onIssue,
    required this.onScan,
  });

  final String? userName;
  final DashboardTotals totals;
  final VoidCallback onProducts;
  final VoidCallback onReceive;
  final VoidCallback onIssue;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF15372C) : const Color(0xFF1F5C4A);
    const fg = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.72);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'StockFlow',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (userName != null)
                          Text(
                            'Hello, $userName',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: soft,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      (userName ?? '?').characters.first.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Units on hand',
                style: theme.textTheme.labelLarge?.copyWith(color: soft),
              ),
              const SizedBox(height: 2),
              Text(
                '${totals.unitsOnHand}',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                  height: 1.1,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              InkWell(
                key: const Key('tile_products'),
                onTap: onProducts,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'across ${totals.products} products',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: soft,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: soft),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      key: const Key('quick_receive'),
                      icon: Icons.south_west_rounded,
                      label: 'Receive',
                      onTap: onReceive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      key: const Key('quick_issue'),
                      icon: Icons.north_east_rounded,
                      label: 'Issue',
                      onTap: onIssue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      key: const Key('quick_scan'),
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan',
                      onTap: onScan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.container,
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color container;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = value > 0;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? container : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: active ? color : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: theme.textTheme.titleLarge?.copyWith(
                        height: 1.1,
                        color: active ? color : scheme.onSurface,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
        SectionHeader(
          title: title,
          trailing: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        Card(clipBehavior: Clip.antiAlias, child: child),
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
        ? (scheme.error, 'Out of stock', Icons.block_rounded)
        : (scheme.tertiary, 'Low stock', Icons.trending_down_rounded);
    return ListTile(
      leading: Icon(icon, color: color, semanticLabel: label),
      title: Text(item.name),
      subtitle: Text('${item.sku} · min ${item.minStock} ${item.unit}'),
      trailing: Text(
        '${item.onHand} ${item.unit}',
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700, color: color),
      ),
      onTap: () => context.push('/products/${item.id}'),
    );
  }
}
