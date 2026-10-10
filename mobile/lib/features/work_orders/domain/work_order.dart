import '../../auth/domain/user.dart';
import '../../operations/domain/stock_transaction.dart';

enum WoStatus {
  open('OPEN', 'Open'),
  inProgress('IN_PROGRESS', 'In progress'),
  submitted('SUBMITTED', 'Submitted'),
  needsRevision('NEEDS_REVISION', 'Needs revision'),
  approved('APPROVED', 'Approved'),
  cancelled('CANCELLED', 'Cancelled');

  const WoStatus(this.api, this.label);

  final String api;
  final String label;

  bool get isClosed => this == approved || this == cancelled;

  static WoStatus fromApi(String v) => values.firstWhere((s) => s.api == v);
}

enum WoPriority {
  low('LOW', 'Low'),
  normal('NORMAL', 'Normal'),
  high('HIGH', 'High'),
  urgent('URGENT', 'Urgent');

  const WoPriority(this.api, this.label);

  final String api;
  final String label;

  static WoPriority fromApi(String v) => values.firstWhere((p) => p.api == v);
}

enum EvidenceCategory {
  before('BEFORE', 'Before'),
  after('AFTER', 'After'),
  other('OTHER', 'Other');

  const EvidenceCategory(this.api, this.label);

  final String api;
  final String label;

  static EvidenceCategory fromApi(String v) =>
      values.firstWhere((c) => c.api == v);
}

/// Actions the server says the current user may take right now.
enum WoAction {
  assign,
  start,
  updateChecklist,
  manageEvidence,
  submit,
  approve,
  requestChanges,
  cancel;

  static WoAction? fromApi(String v) =>
      values.where((a) => a.name == v).firstOrNull;
}

class Person {
  const Person({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final Role role;

  static Person? maybe(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      role: Role.fromApi(json['role'] as String),
    );
  }
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

/// Row in the work-order list.
class WorkOrderSummary {
  const WorkOrderSummary({
    required this.id,
    required this.code,
    required this.title,
    required this.siteName,
    required this.status,
    required this.priority,
    required this.checklistDone,
    required this.checklistTotal,
    this.dueAt,
    this.assignee,
  });

  final String id;
  final String code;
  final String title;
  final String siteName;
  final WoStatus status;
  final WoPriority priority;
  final DateTime? dueAt;
  final Person? assignee;
  final int checklistDone;
  final int checklistTotal;

  bool get isOverdue =>
      dueAt != null && !status.isClosed && dueAt!.isBefore(DateTime.now());

  factory WorkOrderSummary.fromJson(Map<String, dynamic> j) => WorkOrderSummary(
    id: j['id'] as String,
    code: j['code'] as String,
    title: j['title'] as String,
    siteName: j['siteName'] as String,
    status: WoStatus.fromApi(j['status'] as String),
    priority: WoPriority.fromApi(j['priority'] as String),
    dueAt: _date(j['dueAt']),
    assignee: Person.maybe(j['assignee']),
    checklistDone: j['checklistDone'] as int? ?? 0,
    checklistTotal: j['checklistTotal'] as int? ?? 0,
  );
}

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    required this.required,
    required this.done,
    this.description,
    this.note,
    this.completedBy,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final bool required;
  final bool done;
  final String? note;
  final Person? completedBy;
  final DateTime? completedAt;

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    required: j['required'] as bool,
    done: j['done'] as bool,
    note: j['note'] as String?,
    completedBy: Person.maybe(j['completedBy']),
    completedAt: _date(j['completedAt']),
  );
}

class WoMaterial {
  const WoMaterial({
    required this.productId,
    required this.sku,
    required this.name,
    required this.unit,
    required this.onHand,
    required this.plannedQty,
    required this.issuedQty,
    required this.remainingQty,
    required this.shortage,
    this.imageUrl,
  });

  final String productId;
  final String sku;
  final String name;
  final String unit;
  final int onHand;
  final String? imageUrl;
  final int plannedQty;
  final int issuedQty;
  final int remainingQty;
  final int shortage;

  factory WoMaterial.fromJson(Map<String, dynamic> j) {
    final p = j['product'] as Map<String, dynamic>;
    return WoMaterial(
      productId: p['id'] as String,
      sku: p['sku'] as String,
      name: p['name'] as String,
      unit: p['unit'] as String,
      onHand: p['onHand'] as int,
      imageUrl: p['imageUrl'] as String?,
      plannedQty: j['plannedQty'] as int,
      issuedQty: j['issuedQty'] as int,
      remainingQty: j['remainingQty'] as int,
      shortage: j['shortage'] as int,
    );
  }
}

class WoEvidence {
  const WoEvidence({
    required this.id,
    required this.category,
    required this.url,
    required this.createdAt,
    this.note,
    this.uploadedBy,
  });

  final String id;
  final EvidenceCategory category;
  final String url;
  final String? note;
  final Person? uploadedBy;
  final DateTime createdAt;

  String thumbnailUrl([int size = 300]) => url.replaceFirst(
    '/image/upload/',
    '/image/upload/c_fill,w_$size,h_$size,q_auto,f_auto/',
  );

  factory WoEvidence.fromJson(Map<String, dynamic> j) => WoEvidence(
    id: j['id'] as String,
    category: EvidenceCategory.fromApi(j['category'] as String),
    url: j['url'] as String,
    note: j['note'] as String?,
    uploadedBy: Person.maybe(j['uploadedBy']),
    createdAt: _date(j['createdAt'])!,
  );
}

/// A stock document linked to the work order.
class LinkedDocument {
  const LinkedDocument({
    required this.id,
    required this.type,
    required this.status,
    required this.itemCount,
    required this.createdAt,
    this.referenceNo,
  });

  final String id;
  final TxType type;
  final TxStatus status;
  final String? referenceNo;
  final int itemCount;
  final DateTime createdAt;

  factory LinkedDocument.fromJson(Map<String, dynamic> j) => LinkedDocument(
    id: j['id'] as String,
    type: TxType.fromApi(j['type'] as String),
    status: TxStatus.fromApi(j['status'] as String),
    referenceNo: j['referenceNo'] as String?,
    itemCount: j['itemCount'] as int? ?? 0,
    createdAt: _date(j['createdAt'])!,
  );
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.code,
    required this.title,
    required this.siteName,
    required this.status,
    required this.priority,
    required this.requiredEvidence,
    required this.checklist,
    required this.materials,
    required this.evidence,
    required this.documents,
    required this.allowedActions,
    required this.submissionProblems,
    required this.createdAt,
    this.description,
    this.siteAddress,
    this.dueAt,
    this.assignee,
    this.reviewer,
    this.reviewedBy,
    this.createdBy,
    this.templateName,
    this.reviewNote,
    this.cancelReason,
    this.startedAt,
    this.submittedAt,
    this.reviewedAt,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final String siteName;
  final String? siteAddress;
  final WoStatus status;
  final WoPriority priority;
  final DateTime? dueAt;
  final List<EvidenceCategory> requiredEvidence;
  final Person? assignee;
  final Person? reviewer;
  final Person? reviewedBy;
  final Person? createdBy;
  final String? templateName;
  final String? reviewNote;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final List<ChecklistItem> checklist;
  final List<WoMaterial> materials;
  final List<WoEvidence> evidence;
  final List<LinkedDocument> documents;
  final Set<WoAction> allowedActions;
  final List<String> submissionProblems;

  bool can(WoAction a) => allowedActions.contains(a);

  int get checklistDone => checklist.where((i) => i.done).length;

  bool get isOverdue =>
      dueAt != null && !status.isClosed && dueAt!.isBefore(DateTime.now());

  factory WorkOrder.fromJson(Map<String, dynamic> j) => WorkOrder(
    id: j['id'] as String,
    code: j['code'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    siteName: j['siteName'] as String,
    siteAddress: j['siteAddress'] as String?,
    status: WoStatus.fromApi(j['status'] as String),
    priority: WoPriority.fromApi(j['priority'] as String),
    dueAt: _date(j['dueAt']),
    requiredEvidence: [
      for (final c in (j['requiredEvidence'] as List? ?? const []))
        EvidenceCategory.fromApi(c as String),
    ],
    assignee: Person.maybe(j['assignee']),
    reviewer: Person.maybe(j['reviewer']),
    reviewedBy: Person.maybe(j['reviewedBy']),
    createdBy: Person.maybe(j['createdBy']),
    templateName: (j['template'] as Map<String, dynamic>?)?['name'] as String?,
    reviewNote: j['reviewNote'] as String?,
    cancelReason: j['cancelReason'] as String?,
    createdAt: _date(j['createdAt'])!,
    startedAt: _date(j['startedAt']),
    submittedAt: _date(j['submittedAt']),
    reviewedAt: _date(j['reviewedAt']),
    checklist: [
      for (final i in j['checklist'] as List? ?? const [])
        ChecklistItem.fromJson(i as Map<String, dynamic>),
    ],
    materials: [
      for (final m in j['materials'] as List? ?? const [])
        WoMaterial.fromJson(m as Map<String, dynamic>),
    ],
    evidence: [
      for (final e in j['evidence'] as List? ?? const [])
        WoEvidence.fromJson(e as Map<String, dynamic>),
    ],
    documents: [
      for (final d in j['stockTransactions'] as List? ?? const [])
        LinkedDocument.fromJson(d as Map<String, dynamic>),
    ],
    allowedActions: {
      for (final a in j['allowedActions'] as List? ?? const [])
        ?WoAction.fromApi(a as String),
    },
    submissionProblems: [
      for (final p in j['submissionProblems'] as List? ?? const []) p as String,
    ],
  );
}

class WoEvent {
  const WoEvent({
    required this.id,
    required this.type,
    required this.createdAt,
    this.actor,
    this.note,
    this.toStatus,
  });

  final String id;
  final String type;
  final Person? actor;
  final String? note;
  final WoStatus? toStatus;
  final DateTime createdAt;

  String get label => switch (type) {
    'CREATED' => 'Created',
    'ASSIGNED' => 'Assignment',
    'STARTED' => 'Work started',
    'CHECKLIST_UPDATED' => 'Checklist',
    'EVIDENCE_ADDED' => 'Photo added',
    'EVIDENCE_REMOVED' => 'Photo removed',
    'SUBMITTED' => 'Submitted for review',
    'CHANGES_REQUESTED' => 'Changes requested',
    'APPROVED' => 'Approved',
    'CANCELLED' => 'Cancelled',
    'MATERIAL_ISSUED' => 'Materials',
    _ => type,
  };

  factory WoEvent.fromJson(Map<String, dynamic> j) => WoEvent(
    id: j['id'] as String,
    type: j['type'] as String,
    actor: Person.maybe(j['actor']),
    note: j['note'] as String?,
    toStatus: j['toStatus'] == null
        ? null
        : WoStatus.fromApi(j['toStatus'] as String),
    createdAt: _date(j['createdAt'])!,
  );
}

class ChecklistTemplate {
  const ChecklistTemplate({
    required this.id,
    required this.name,
    required this.itemCount,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final int itemCount;

  factory ChecklistTemplate.fromJson(Map<String, dynamic> j) =>
      ChecklistTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        itemCount: (j['items'] as List? ?? const []).length,
      );
}
