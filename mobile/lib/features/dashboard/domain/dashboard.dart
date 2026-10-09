import '../../operations/domain/stock_transaction.dart';

class DashboardTotals {
  const DashboardTotals({
    required this.products,
    required this.unitsOnHand,
    required this.lowStock,
    required this.outOfStock,
    required this.pendingDrafts,
  });

  final int products;
  final int unitsOnHand;
  final int lowStock;
  final int outOfStock;
  final int pendingDrafts;

  factory DashboardTotals.fromJson(Map<String, dynamic> j) => DashboardTotals(
    products: j['products'] as int,
    unitsOnHand: j['unitsOnHand'] as int,
    lowStock: j['lowStock'] as int,
    outOfStock: j['outOfStock'] as int,
    pendingDrafts: j['pendingDrafts'] as int,
  );
}

class DayFlow {
  const DayFlow({
    required this.date,
    required this.received,
    required this.issued,
  });

  final DateTime date;
  final int received;
  final int issued;

  factory DayFlow.fromJson(Map<String, dynamic> j) => DayFlow(
    date: DateTime.parse(j['date'] as String),
    received: j['received'] as int,
    issued: j['issued'] as int,
  );
}

class AttentionItem {
  const AttentionItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.onHand,
    required this.minStock,
  });

  final String id;
  final String sku;
  final String name;
  final String unit;
  final int onHand;
  final int minStock;

  bool get isOut => onHand <= 0;

  factory AttentionItem.fromJson(Map<String, dynamic> j) => AttentionItem(
    id: j['id'] as String,
    sku: j['sku'] as String,
    name: j['name'] as String,
    unit: j['unit'] as String,
    onHand: j['onHand'] as int,
    minStock: j['minStock'] as int,
  );
}

class RecentActivity {
  const RecentActivity({
    required this.id,
    required this.type,
    required this.confirmedAt,
    required this.itemCount,
    this.referenceNo,
    this.confirmedBy,
  });

  final String id;
  final TxType type;
  final String? referenceNo;
  final DateTime confirmedAt;
  final String? confirmedBy;
  final int itemCount;

  factory RecentActivity.fromJson(Map<String, dynamic> j) => RecentActivity(
    id: j['id'] as String,
    type: TxType.fromApi(j['type'] as String),
    referenceNo: j['referenceNo'] as String?,
    confirmedAt: DateTime.parse(j['confirmedAt'] as String).toLocal(),
    confirmedBy: j['confirmedBy'] as String?,
    itemCount: j['itemCount'] as int,
  );
}

class DashboardSummary {
  const DashboardSummary({
    required this.totals,
    required this.flow,
    required this.needsAttention,
    required this.recentActivity,
  });

  final DashboardTotals totals;
  final List<DayFlow> flow;
  final List<AttentionItem> needsAttention;
  final List<RecentActivity> recentActivity;

  int get weekReceived => flow.fold(0, (s, d) => s + d.received);
  int get weekIssued => flow.fold(0, (s, d) => s + d.issued);

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
    totals: DashboardTotals.fromJson(j['totals'] as Map<String, dynamic>),
    flow: (j['flow'] as List)
        .map((e) => DayFlow.fromJson(e as Map<String, dynamic>))
        .toList(),
    needsAttention: (j['needsAttention'] as List)
        .map((e) => AttentionItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    recentActivity: (j['recentActivity'] as List)
        .map((e) => RecentActivity.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
