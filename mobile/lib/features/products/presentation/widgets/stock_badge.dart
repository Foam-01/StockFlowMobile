import 'package:flutter/material.dart';

import '../../domain/product.dart';

/// On-hand quantity, coloured by stock level.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product, this.large = false});

  final Product product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, label) = product.isOutOfStock
        ? (scheme.errorContainer, scheme.onErrorContainer, 'Out of stock')
        : product.isLowStock
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer, 'Low stock')
        : (scheme.secondaryContainer, scheme.onSecondaryContainer, 'In stock');

    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '${product.onHand} ${product.unit}, $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 10,
          vertical: large ? 8 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product.onHand}',
              style: (large ? text.headlineSmall : text.titleMedium)?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              large ? label : product.unit,
              style: text.labelSmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
