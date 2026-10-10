import '../../operations/domain/draft.dart';
import '../../products/domain/product.dart';
import '../domain/work_order.dart';

/// Pre-fills an ISSUE document with what a work order still needs, and
/// links the document to it.
class IssueForWorkOrder {
  const IssueForWorkOrder({
    required this.workOrderId,
    required this.code,
    required this.lines,
  });

  final String workOrderId;
  final String code;
  final List<DraftLine> lines;

  factory IssueForWorkOrder.fromWorkOrder(WorkOrder wo) => IssueForWorkOrder(
    workOrderId: wo.id,
    code: wo.code,
    lines: [
      for (final m in wo.materials)
        if (m.remainingQty > 0)
          DraftLine(
            product: Product(
              id: m.productId,
              sku: m.sku,
              name: m.name,
              unit: m.unit,
              minStock: 0,
              onHand: m.onHand,
              imageUrl: m.imageUrl,
            ),
            // Never pre-fill more than is on hand; the user can adjust.
            quantity: m.remainingQty.clamp(1, m.onHand < 1 ? 1 : m.onHand),
          ),
    ],
  );
}
