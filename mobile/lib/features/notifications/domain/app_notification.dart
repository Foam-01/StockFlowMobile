/// One in-app notice about a work order (server-generated).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.workOrderId,
    required this.workOrderCode,
    required this.workOrderTitle,
    required this.read,
    required this.createdAt,
    this.actorName,
    this.note,
  });

  final String id;

  /// Server event type: ASSIGNED, SUBMITTED, CHANGES_REQUESTED, APPROVED,
  /// CANCELLED.
  final String type;
  final String workOrderId;
  final String workOrderCode;
  final String workOrderTitle;
  final String? actorName;
  final String? note;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    workOrderId: workOrderId,
    workOrderCode: workOrderCode,
    workOrderTitle: workOrderTitle,
    actorName: actorName,
    note: note,
    read: read ?? this.read,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final wo = j['workOrder'] as Map<String, dynamic>;
    final actor = j['actor'] as Map<String, dynamic>?;
    return AppNotification(
      id: j['id'] as String,
      type: j['type'] as String,
      workOrderId: wo['id'] as String,
      workOrderCode: wo['code'] as String,
      workOrderTitle: wo['title'] as String,
      actorName: actor?['name'] as String?,
      note: j['note'] as String?,
      read: j['read'] as bool,
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
    );
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.total,
    required this.unread,
    required this.page,
  });

  final List<AppNotification> items;
  final int total;
  final int unread;
  final int page;

  factory NotificationPage.fromJson(Map<String, dynamic> j) => NotificationPage(
    items: [
      for (final e in j['items'] as List)
        AppNotification.fromJson(e as Map<String, dynamic>),
    ],
    total: j['total'] as int,
    unread: j['unread'] as int,
    page: j['page'] as int,
  );
}
