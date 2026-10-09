import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../products/domain/product.dart';
import '../domain/stock_transaction.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>(
  (ref) => ApiOperationsRepository(ref.watch(dioProvider)),
);

abstract class OperationsRepository {
  Future<Paged<StockTransaction>> list({
    TxStatus? status,
    int page = 1,
    int limit = 20,
  });
  Future<StockTransaction> get(String id);

  /// Creates a DRAFT. Resending the same [clientUuid] returns the original.
  Future<StockTransaction> create({
    required String clientUuid,
    required TxType type,
    required List<({String productId, int quantity})> items,
    String? referenceNo,
    String? note,
  });
  Future<StockTransaction> confirm(String id);
  Future<StockTransaction> cancel(String id);
}

class ApiOperationsRepository implements OperationsRepository {
  ApiOperationsRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  StockTransaction _tx(Response<Map<String, dynamic>> res) =>
      StockTransaction.fromJson(res.data!);

  @override
  Future<Paged<StockTransaction>> list({
    TxStatus? status,
    int page = 1,
    int limit = 20,
  }) => _call(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/transactions',
      queryParameters: {'status': ?status?.api, 'page': page, 'limit': limit},
    );
    final data = res.data!;
    return Paged(
      items: (data['items'] as List)
          .map((e) => StockTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int,
      page: data['page'] as int,
    );
  });

  @override
  Future<StockTransaction> get(String id) => _call(
    () async => _tx(await _dio.get<Map<String, dynamic>>('/transactions/$id')),
  );

  @override
  Future<StockTransaction> create({
    required String clientUuid,
    required TxType type,
    required List<({String productId, int quantity})> items,
    String? referenceNo,
    String? note,
  }) => _call(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/transactions',
      data: {
        'clientUuid': clientUuid,
        'type': type.api,
        if (referenceNo != null && referenceNo.isNotEmpty)
          'referenceNo': referenceNo,
        if (note != null && note.isNotEmpty) 'note': note,
        'items': [
          for (final i in items)
            {'productId': i.productId, 'quantity': i.quantity},
        ],
      },
    );
    return _tx(res);
  });

  @override
  Future<StockTransaction> confirm(String id) => _call(
    () async =>
        _tx(await _dio.post<Map<String, dynamic>>('/transactions/$id/confirm')),
  );

  @override
  Future<StockTransaction> cancel(String id) => _call(
    () async =>
        _tx(await _dio.post<Map<String, dynamic>>('/transactions/$id/cancel')),
  );
}
