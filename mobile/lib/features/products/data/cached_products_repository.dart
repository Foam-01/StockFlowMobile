import '../../../core/errors.dart';
import '../../offline/data/local_store.dart';
import '../domain/product.dart';
import 'products_repository.dart';

/// Network-first products: results are cached locally, and when the API
/// can't be reached the last-known products are served instead.
class CachedProductsRepository implements ProductsRepository {
  CachedProductsRepository(this._api, this._cache);

  final ProductsRepository _api;
  final ProductCache _cache;

  Future<T> _orCache<T>(
    Future<T> Function() online,
    Future<T?> Function() offline,
  ) async {
    try {
      return await online();
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final cached = await offline();
      if (cached == null) rethrow;
      return cached;
    }
  }

  @override
  Future<Paged<Product>> list({
    String? query,
    String? categoryId,
    bool lowStock = false,
    int page = 1,
    int limit = 20,
  }) => _orCache(
    () async {
      final result = await _api.list(
        query: query,
        categoryId: categoryId,
        lowStock: lowStock,
        page: page,
        limit: limit,
      );
      await _cache.putAll(result.items);
      return result;
    },
    () async {
      final all = await _cache.search(
        query: query,
        categoryId: categoryId,
        lowStock: lowStock,
      );
      if (all.isEmpty && page == 1) return null; // nothing cached: show error
      return Paged(
        items: all.skip((page - 1) * limit).take(limit).toList(),
        total: all.length,
        page: page,
      );
    },
  );

  @override
  Future<Product> get(String id) => _orCache(() async {
    final p = await _api.get(id);
    await _cache.putAll([p]);
    return p;
  }, () => _cache.byId(id));

  @override
  Future<Product> getByBarcode(String barcode) => _orCache(() async {
    final p = await _api.getByBarcode(barcode);
    await _cache.putAll([p]);
    return p;
  }, () => _cache.byBarcode(barcode));

  @override
  Future<List<Category>> categories() => _orCache(_api.categories, () async {
    final byId = <String, Category>{
      for (final p in await _cache.search())
        if (p.category != null) p.category!.id: p.category!,
    };
    if (byId.isEmpty) return null;
    return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  });
}
