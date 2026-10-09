import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../domain/product.dart';

final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ApiProductsRepository(ref.watch(dioProvider)),
);

abstract class ProductsRepository {
  Future<Paged<Product>> list({
    String? query,
    String? categoryId,
    bool lowStock = false,
    int page = 1,
    int limit = 20,
  });
  Future<Product> get(String id);
  Future<Product> getByBarcode(String barcode);
  Future<List<Category>> categories();
}

class ApiProductsRepository implements ProductsRepository {
  ApiProductsRepository(this._dio);

  final Dio _dio;

  @override
  Future<Paged<Product>> list({
    String? query,
    String? categoryId,
    bool lowStock = false,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/products',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          'categoryId': ?categoryId,
          if (lowStock) 'lowStock': true,
          'page': page,
          'limit': limit,
        },
      );
      final data = res.data!;
      return Paged(
        items: (data['items'] as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: data['total'] as int,
        page: data['page'] as int,
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<Product> get(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/products/$id');
      return Product.fromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<Product> getByBarcode(String barcode) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/products/barcode/${Uri.encodeComponent(barcode)}',
      );
      return Product.fromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<List<Category>> categories() async {
    try {
      final res = await _dio.get<List<dynamic>>('/categories');
      return res.data!
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
