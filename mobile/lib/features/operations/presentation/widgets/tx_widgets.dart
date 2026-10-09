import 'package:flutter/material.dart';

import '../../domain/stock_transaction.dart';

String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class TxStatusChip extends StatelessWidget {
  const TxStatusChip({super.key, required this.status});

  final TxStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      TxStatus.draft => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      TxStatus.confirmed => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      TxStatus.cancelled => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Coloured square with the transaction type icon.
class TxTypeIcon extends StatelessWidget {
  const TxTypeIcon({super.key, required this.type});

  final TxType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (type) {
      TxType.receive => scheme.primary,
      TxType.issue => scheme.error,
      TxType.adjust => scheme.tertiary,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(type.icon, size: 22, color: color, semanticLabel: type.label),
    );
  }
}

/// "+5" / "−3" with colour.
class SignedQty extends StatelessWidget {
  const SignedQty({super.key, required this.value, this.unit});

  final int value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = value > 0 ? '+$value' : '−${value.abs()}';
    return Text(
      unit == null ? text : '$text $unit',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: value > 0 ? scheme.primary : scheme.error,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
