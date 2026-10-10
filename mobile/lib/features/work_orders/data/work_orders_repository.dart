import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/l10n.dart';
import '../../products/domain/product.dart';
import '../domain/work_order.dart';

final workOrdersRepositoryProvider = Provider<WorkOrdersRepository>(
  (ref) => ApiWorkOrdersRepository(
    ref.watch(dioProvider),
    // Separate client for Cloudinary: it must never receive our JWT.
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
  ),
);

class NewWorkOrder {
  const NewWorkOrder({
    required this.clientUuid,
    required this.title,
    required this.siteName,
    required this.priority,
    this.description,
    this.siteAddress,
    this.dueAt,
    this.assigneeId,
    this.reviewerId,
    this.templateId,
    this.requiredEvidence = const [],
    this.materials = const [],
  });

  final String clientUuid;
  final String title;
  final String? description;
  final String siteName;
  final String? siteAddress;
  final WoPriority priority;
  final DateTime? dueAt;
  final String? assigneeId;
  final String? reviewerId;
  final String? templateId;
  final List<EvidenceCategory> requiredEvidence;
  final List<({String productId, int plannedQty})> materials;

  Map<String, dynamic> toJson() => {
    'clientUuid': clientUuid,
    'title': title,
    if (description?.isNotEmpty ?? false) 'description': description,
    'siteName': siteName,
    if (siteAddress?.isNotEmpty ?? false) 'siteAddress': siteAddress,
    'priority': priority.api,
    if (dueAt != null) 'dueAt': dueAt!.toUtc().toIso8601String(),
    'assigneeId': ?assigneeId,
    'reviewerId': ?reviewerId,
    'templateId': ?templateId,
    'requiredEvidence': [for (final c in requiredEvidence) c.api],
    'materials': [
      for (final m in materials)
        {'productId': m.productId, 'plannedQty': m.plannedQty},
    ],
  };
}

abstract class WorkOrdersRepository {
  Future<Paged<WorkOrderSummary>> list({
    Set<WoStatus> statuses = const {},
    String? query,
    int page = 1,
    int limit = 20,
  });
  Future<WorkOrder> get(String id);
  Future<List<WoEvent>> events(String id);
  Future<WorkOrder> create(NewWorkOrder order);
  Future<WorkOrder> assign(String id, {String? assigneeId, String? reviewerId});
  Future<WorkOrder> start(String id);
  Future<WorkOrder> setChecklistItem(
    String id,
    String itemId, {
    required bool done,
    String? note,
  });
  Future<WorkOrder> submit(String id);
  Future<WorkOrder> approve(String id, {String? note});
  Future<WorkOrder> requestChanges(String id, String reason);
  Future<WorkOrder> cancel(String id, String reason);
  Future<WorkOrder> uploadEvidence(
    String id,
    EvidenceCategory category,
    Uint8List bytes,
    String filename, {
    String? note,
    void Function(double progress)? onProgress,
  });
  Future<WorkOrder> removeEvidence(String id, String evidenceId);
  Future<List<ChecklistTemplate>> templates();
  Future<List<Person>> people(String role);
}

class ApiWorkOrdersRepository implements WorkOrdersRepository {
  ApiWorkOrdersRepository(this._api, this._cdn);

  final Dio _api;
  final Dio _cdn;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<WorkOrder> _wo(Future<Response<Map<String, dynamic>>> req) =>
      _call(() async => WorkOrder.fromJson((await req).data!));

  @override
  Future<Paged<WorkOrderSummary>> list({
    Set<WoStatus> statuses = const {},
    String? query,
    int page = 1,
    int limit = 20,
  }) => _call(() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/work-orders',
      queryParameters: {
        if (statuses.isNotEmpty) 'status': statuses.map((s) => s.api).join(','),
        if (query != null && query.isNotEmpty) 'q': query,
        'page': page,
        'limit': limit,
      },
    );
    final d = res.data!;
    return Paged(
      items: [
        for (final e in d['items'] as List)
          WorkOrderSummary.fromJson(e as Map<String, dynamic>),
      ],
      total: d['total'] as int,
      page: d['page'] as int,
    );
  });

  @override
  Future<WorkOrder> get(String id) =>
      _wo(_api.get<Map<String, dynamic>>('/work-orders/$id'));

  @override
  Future<List<WoEvent>> events(String id) => _call(() async {
    final res = await _api.get<List<dynamic>>('/work-orders/$id/events');
    return [
      for (final e in res.data!) WoEvent.fromJson(e as Map<String, dynamic>),
    ];
  });

  @override
  Future<WorkOrder> create(NewWorkOrder order) => _wo(
    _api.post<Map<String, dynamic>>('/work-orders', data: order.toJson()),
  );

  @override
  Future<WorkOrder> assign(
    String id, {
    String? assigneeId,
    String? reviewerId,
  }) => _wo(
    _api.patch<Map<String, dynamic>>(
      '/work-orders/$id/assignment',
      data: {'assigneeId': assigneeId, 'reviewerId': reviewerId},
    ),
  );

  @override
  Future<WorkOrder> start(String id) =>
      _wo(_api.post<Map<String, dynamic>>('/work-orders/$id/start'));

  @override
  Future<WorkOrder> setChecklistItem(
    String id,
    String itemId, {
    required bool done,
    String? note,
  }) => _wo(
    _api.put<Map<String, dynamic>>(
      '/work-orders/$id/checklist/$itemId',
      data: {'done': done, 'note': ?note},
    ),
  );

  @override
  Future<WorkOrder> submit(String id) =>
      _wo(_api.post<Map<String, dynamic>>('/work-orders/$id/submit'));

  @override
  Future<WorkOrder> approve(String id, {String? note}) => _wo(
    _api.post<Map<String, dynamic>>(
      '/work-orders/$id/approve',
      data: {if (note != null && note.isNotEmpty) 'note': note},
    ),
  );

  @override
  Future<WorkOrder> requestChanges(String id, String reason) => _wo(
    _api.post<Map<String, dynamic>>(
      '/work-orders/$id/request-changes',
      data: {'reason': reason},
    ),
  );

  @override
  Future<WorkOrder> cancel(String id, String reason) => _wo(
    _api.post<Map<String, dynamic>>(
      '/work-orders/$id/cancel',
      data: {'reason': reason},
    ),
  );

  @override
  Future<WorkOrder> uploadEvidence(
    String id,
    EvidenceCategory category,
    Uint8List bytes,
    String filename, {
    String? note,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // 1. Short-lived signature for this work order's folder.
      final sig = (await _api.post<Map<String, dynamic>>(
        '/work-orders/$id/evidence/signature',
        data: {'category': category.api},
      )).data!;
      // 2. Straight to Cloudinary with exactly the signed fields.
      final uploaded = (await _cdn.post<Map<String, dynamic>>(
        sig['uploadUrl'] as String,
        data: FormData.fromMap({
          ...(sig['fields'] as Map<String, dynamic>),
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        }),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      )).data!;
      // 3. The API checks it is ours and in the right folder before saving.
      final res = await _api.post<Map<String, dynamic>>(
        '/work-orders/$id/evidence',
        data: {
          'category': category.api,
          'publicId': uploaded['public_id'],
          'url': uploaded['secure_url'],
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      return WorkOrder.fromJson(res.data!);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        throw ApiException(
          l10nNow.uploadFailed('${(data['error'] as Map)['message']}'),
          statusCode: e.response?.statusCode,
        );
      }
      throw ApiException.from(e);
    }
  }

  @override
  Future<WorkOrder> removeEvidence(String id, String evidenceId) => _wo(
    _api.delete<Map<String, dynamic>>('/work-orders/$id/evidence/$evidenceId'),
  );

  @override
  Future<List<ChecklistTemplate>> templates() => _call(() async {
    final res = await _api.get<List<dynamic>>('/checklist-templates');
    return [
      for (final t in res.data!)
        ChecklistTemplate.fromJson(t as Map<String, dynamic>),
    ];
  });

  @override
  Future<List<Person>> people(String role) => _call(() async {
    final res = await _api.get<List<dynamic>>(
      '/users',
      queryParameters: {'role': role},
    );
    return [for (final u in res.data!) Person.maybe(u)!];
  });
}
