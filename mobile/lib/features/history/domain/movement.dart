import '../../operations/domain/stock_transaction.dart';

/// One confirmed stock change for a product, with the balance right after it.
class Movement {
  const Movement({
    required this.transactionId,
    required this.type,
    required this.change,
    required this.balanceAfter,
    required this.confirmedAt,
    required this.createdBy,
    this.confirmedBy,
    this.referenceNo,
    this.note,
  });

  final String transactionId;
  final TxType type;
  final int change;
  final int balanceAfter;
  final DateTime confirmedAt;
  final String createdBy;
  final String? confirmedBy;
  final String? referenceNo;
  final String? note;

  factory Movement.fromJson(Map<String, dynamic> json) => Movement(
    transactionId: json['transactionId'] as String,
    type: TxType.fromApi(json['type'] as String),
    change: json['change'] as int,
    balanceAfter: json['balanceAfter'] as int,
    confirmedAt: DateTime.parse(json['confirmedAt'] as String).toLocal(),
    createdBy: json['createdBy'] as String,
    confirmedBy: json['confirmedBy'] as String?,
    referenceNo: json['referenceNo'] as String?,
    note: json['note'] as String?,
  );
}

class MovementPage {
  const MovementPage({
    required this.items,
    required this.total,
    required this.page,
    required this.unit,
    required this.onHand,
  });

  final List<Movement> items;
  final int total;
  final int page;
  final String unit;
  final int onHand;
}
