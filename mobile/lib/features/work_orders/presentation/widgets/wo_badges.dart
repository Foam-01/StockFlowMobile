import 'package:flutter/material.dart';

import '../../domain/work_order.dart';
import '../../../../core/l10n.dart';

String formatDue(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Status pill: colour always paired with the label.
class WoStatusChip extends StatelessWidget {
  const WoStatusChip({super.key, required this.status});

  final WoStatus status;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      WoStatus.open => (s.surfaceContainerHighest, s.onSurfaceVariant),
      WoStatus.inProgress => (s.secondaryContainer, s.onSecondaryContainer),
      WoStatus.submitted => (s.tertiaryContainer, s.onTertiaryContainer),
      WoStatus.needsRevision => (s.errorContainer, s.onErrorContainer),
      WoStatus.approved => (s.primaryContainer, s.onPrimaryContainer),
      WoStatus.cancelled => (s.surfaceContainerHigh, s.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.tr(context.l10n),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Only HIGH and URGENT get a visible badge, so they stand out.
class WoPriorityBadge extends StatelessWidget {
  const WoPriorityBadge({super.key, required this.priority});

  final WoPriority priority;

  @override
  Widget build(BuildContext context) {
    if (priority == WoPriority.low || priority == WoPriority.normal) {
      return const SizedBox.shrink();
    }
    final s = Theme.of(context).colorScheme;
    final urgent = priority == WoPriority.urgent;
    final color = urgent ? s.error : s.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          urgent ? Icons.priority_high_rounded : Icons.keyboard_double_arrow_up,
          size: 16,
          color: color,
        ),
        Text(
          priority.tr(context.l10n),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// "Due 12/10 14:00", red with an icon when overdue.
class WoDue extends StatelessWidget {
  const WoDue({super.key, required this.dueAt, required this.overdue});

  final DateTime? dueAt;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    if (dueAt == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = overdue
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          overdue ? Icons.schedule_rounded : Icons.event_outlined,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          overdue
              ? context.l10n.overdueAt(formatDue(dueAt!))
              : context.l10n.dueAt(formatDue(dueAt!)),
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: overdue ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}
