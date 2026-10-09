import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../domain/product.dart';

/// On-hand quantity. Healthy stock stays neutral; low and out of stock add a
/// coloured status line so the eye only stops where action is needed.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product, this.large = false});

  final Product product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (color, label) = product.isOutOfStock
        ? (scheme.error, 'Out of stock')
        : product.isLowStock
        ? (scheme.tertiary, 'Low stock')
        : (scheme.primary, 'In stock');
    final alert = product.isOutOfStock || product.isLowStock;

    return Semantics(
      label: '${product.onHand} ${product.unit}, $label',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: large
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${product.onHand}',
                style: (large ? text.displaySmall : text.titleLarge)?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  letterSpacing: large ? -1 : -0.3,
                  color: alert ? color : scheme.onSurface,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                product.unit,
                style: (large ? text.titleMedium : text.labelMedium)?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (alert || large) ...[
            SizedBox(height: large ? 8 : 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: (large ? text.labelLarge : text.labelSmall)?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
