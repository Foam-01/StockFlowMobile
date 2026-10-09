import 'dart:convert';

import '../../operations/domain/stock_transaction.dart';

enum PendingStatus { pending, failed }

/// A line of a queued document. Product details are kept so the queue can be
/// shown (and reviewed) without a connection.
class PendingLine {
  const PendingLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final String sku;
  final String unit;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'sku': sku,
    'unit': unit,
    'quantity': quantity,
  };

  factory PendingLine.fromJson(Map<String, dynamic> j) => PendingLine(
    productId: j['productId'] as String,
    productName: j['productName'] as String,
    sku: j['sku'] as String,
    unit: j['unit'] as String,
    quantity: j['quantity'] as int,
  );
}

/// A stock document created while offline, waiting to be sent.
///
/// [clientUuid] is generated once when the user saves, and reused on every
/// attempt: the API returns the existing draft for a known clientUuid, so a
/// retry after a lost response can never create a duplicate.
class PendingOp {
  const PendingOp({
    required this.clientUuid,
    required this.type,
    required this.lines,
    required this.createdAt,
    this.referenceNo,
    this.note,
    this.status = PendingStatus.pending,
    this.error,
    this.attempts = 0,
  });

  final String clientUuid;
  final TxType type;
  final List<PendingLine> lines;
  final String? referenceNo;
  final String? note;
  final DateTime createdAt;
  final PendingStatus status;

  /// Why the server rejected it (only when [status] is failed).
  final String? error;
  final int attempts;

  PendingOp copyWith({
    PendingStatus? status,
    String? Function()? error,
    int? attempts,
  }) => PendingOp(
    clientUuid: clientUuid,
    type: type,
    lines: lines,
    referenceNo: referenceNo,
    note: note,
    createdAt: createdAt,
    status: status ?? this.status,
    error: error != null ? error() : this.error,
    attempts: attempts ?? this.attempts,
  );

  /// Row for the `outbox` table.
  Map<String, Object?> toRow() => {
    'client_uuid': clientUuid,
    'type': type.api,
    'lines': jsonEncode([for (final l in lines) l.toJson()]),
    'reference_no': referenceNo,
    'note': note,
    'created_at': createdAt.millisecondsSinceEpoch,
    'status': status.name,
    'error': error,
    'attempts': attempts,
  };

  factory PendingOp.fromRow(Map<String, Object?> r) => PendingOp(
    clientUuid: r['client_uuid']! as String,
    type: TxType.fromApi(r['type']! as String),
    lines: [
      for (final l in jsonDecode(r['lines']! as String) as List)
        PendingLine.fromJson(l as Map<String, dynamic>),
    ],
    referenceNo: r['reference_no'] as String?,
    note: r['note'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
    status: PendingStatus.values.byName(r['status']! as String),
    error: r['error'] as String?,
    attempts: r['attempts']! as int,
  );
}
