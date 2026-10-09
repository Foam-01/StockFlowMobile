import 'package:flutter/material.dart';

enum TxType {
  receive('RECEIVE', 'Receive', Icons.move_to_inbox_outlined),
  issue('ISSUE', 'Issue', Icons.outbox_outlined),
  adjust('ADJUST', 'Adjust', Icons.tune);

  const TxType(this.api, this.label, this.icon);

  final String api;
  final String label;
  final IconData icon;

  static TxType fromApi(String v) => values.firstWhere((t) => t.api == v);
}

enum TxStatus {
  draft('DRAFT', 'Draft'),
  confirmed('CONFIRMED', 'Confirmed'),
  cancelled('CANCELLED', 'Cancelled');

  const TxStatus(this.api, this.label);

  final String api;
  final String label;

  static TxStatus fromApi(String v) => values.firstWhere((s) => s.api == v);
}

class TxItem {
  const TxItem({
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

  factory TxItem.fromJson(Map<String, dynamic> json) {
    final p = json['product'] as Map<String, dynamic>;
    return TxItem(
      productId: json['productId'] as String,
      productName: p['name'] as String,
      sku: p['sku'] as String,
      unit: p['unit'] as String,
      quantity: json['quantity'] as int,
    );
  }
}

class Attachment {
  const Attachment({required this.id, required this.url});

  final String id;
  final String url;

  /// Cloudinary on-the-fly square thumbnail (resized, auto format/quality).
  String thumbnailUrl([int size = 300]) => url.replaceFirst(
    '/image/upload/',
    '/image/upload/c_fill,w_$size,h_$size,q_auto,f_auto/',
  );

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      Attachment(id: json['id'] as String, url: json['url'] as String);
}

class StockTransaction {
  const StockTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.items,
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    this.referenceNo,
    this.note,
    this.confirmedByName,
    this.confirmedAt,
    this.attachments = const [],
  });

  final String id;
  final TxType type;
  final TxStatus status;
  final String? referenceNo;
  final String? note;
  final List<TxItem> items;
  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final String? confirmedByName;
  final DateTime? confirmedAt;
  final List<Attachment> attachments;

  bool get isDraft => status == TxStatus.draft;

  /// Signed quantity as it affects stock (issue is negative).
  int signedQuantity(TxItem item) =>
      type == TxType.issue ? -item.quantity : item.quantity;

  factory StockTransaction.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'] as Map<String, dynamic>;
    final confirmedBy = json['confirmedBy'] as Map<String, dynamic>?;
    return StockTransaction(
      id: json['id'] as String,
      type: TxType.fromApi(json['type'] as String),
      status: TxStatus.fromApi(json['status'] as String),
      referenceNo: json['referenceNo'] as String?,
      note: json['note'] as String?,
      items: (json['items'] as List)
          .map((e) => TxItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdById: json['createdById'] as String,
      createdByName: createdBy['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      confirmedByName: confirmedBy?['name'] as String?,
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String).toLocal(),
      attachments: ((json['attachments'] as List?) ?? const [])
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
