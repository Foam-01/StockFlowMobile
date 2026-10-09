import '../../products/domain/product.dart';
import 'stock_transaction.dart';

/// A line on the new-transaction form.
class DraftLine {
  const DraftLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  DraftLine withQuantity(int q) => DraftLine(product: product, quantity: q);
}

/// Client-side checks mirroring the API rules, so the user gets instant
/// feedback. The server stays the source of truth.
///
/// Returns a form-level error, or null, plus per-product line errors.
({String? form, Map<String, String> lines}) validateDraft(
  TxType type,
  List<DraftLine> lines,
) {
  final errors = <String, String>{};
  if (lines.isEmpty) return (form: 'Add at least one product', lines: errors);

  for (final l in lines) {
    final id = l.product.id;
    switch (type) {
      case TxType.receive:
        if (l.quantity <= 0) errors[id] = 'Must be greater than 0';
      case TxType.issue:
        if (l.quantity <= 0) {
          errors[id] = 'Must be greater than 0';
        } else if (l.quantity > l.product.onHand) {
          errors[id] = 'Only ${l.product.onHand} ${l.product.unit} on hand';
        }
      case TxType.adjust:
        if (l.quantity == 0) {
          errors[id] = 'Must not be 0';
        } else if (l.product.onHand + l.quantity < 0) {
          errors[id] = 'Would go below 0 (on hand ${l.product.onHand})';
        }
    }
  }
  return (form: null, lines: errors);
}

/// Stock level after applying the line, for preview.
int projectedOnHand(TxType type, DraftLine line) => switch (type) {
  TxType.receive => line.product.onHand + line.quantity,
  TxType.issue => line.product.onHand - line.quantity,
  TxType.adjust => line.product.onHand + line.quantity,
};
