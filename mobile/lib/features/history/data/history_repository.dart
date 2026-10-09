import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../domain/movement.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => ApiHistoryRepository(ref.watch(dioProvider)),
);

abstract class HistoryRepository {
  /// Confirmed movements for a product, newest first.
  Future<MovementPage> movements(
    String productId, {
    int page = 1,
    int limit = 20,
  });
}

class ApiHistoryRepository implements HistoryRepository {
  ApiHistoryRepository(this._dio);

  final Dio _dio;

  @override
  Future<MovementPage> movements(
    String productId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/products/$productId/movements',
        queryParameters: {'page': page, 'limit': limit},
      );
      final d = res.data!;
      return MovementPage(
        items: (d['items'] as List)
            .map((e) => Movement.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: d['total'] as int,
        page: d['page'] as int,
        unit: d['unit'] as String,
        onHand: d['onHand'] as int,
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
