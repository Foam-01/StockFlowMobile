import 'package:flutter/material.dart';

import '../../domain/product.dart';

/// Product photo when there is one; otherwise a tile tinted by category so
/// the list still scans by shape and colour.
class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.product, this.size = 56});

  final Product product;
  final double size;

  static const _tints = [
    (Color(0xFFDCEBE4), Color(0xFF1F5C4A)),
    (Color(0xFFFBEBD0), Color(0xFF8F5300)),
    (Color(0xFFE3E8F4), Color(0xFF34497A)),
    (Color(0xFFF3E1E8), Color(0xFF7D3352)),
    (Color(0xFFE9E5F5), Color(0xFF55418A)),
  ];

  static IconData _icon(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('bever') || c.contains('drink')) {
      return Icons.local_drink_outlined;
    }
    if (c.contains('snack') || c.contains('food')) {
      return Icons.cookie_outlined;
    }
    if (c.contains('house') || c.contains('clean')) {
      return Icons.cleaning_services_outlined;
    }
    if (c.contains('station') || c.contains('office')) {
      return Icons.edit_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final key = product.category?.name ?? product.name;
    final (bg, fg) =
        _tints[key.codeUnits.fold(0, (a, b) => a + b) % _tints.length];
    final radius = BorderRadius.circular(size * 0.25);

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? fg.withValues(alpha: 0.28) : bg,
        borderRadius: radius,
      ),
      child: Icon(
        _icon(product.category?.name),
        size: size * 0.46,
        color: dark ? bg : fg,
      ),
    );

    final url = product.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// On hand against twice the minimum: the marker shows where "low" begins.
class StockLevelBar extends StatelessWidget {
  const StockLevelBar({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final full = product.minStock <= 0 ? 1 : product.minStock * 2;
    final ratio = (product.onHand / full).clamp(0.0, 1.0);
    final minAt = product.minStock <= 0 ? 0.0 : 0.5;
    final color = product.isOutOfStock
        ? scheme.error
        : product.isLowStock
        ? scheme.tertiary
        : scheme.primary;

    return ExcludeSemantics(
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                width: c.maxWidth * ratio,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              if (minAt > 0)
                Positioned(
                  left: c.maxWidth * minAt - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: scheme.surface),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
