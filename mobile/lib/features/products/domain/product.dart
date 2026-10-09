class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(id: json['id'] as String, name: json['name'] as String);
}

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.minStock,
    required this.onHand,
    this.barcode,
    this.imageUrl,
    this.category,
  });

  final String id;
  final String sku;
  final String? barcode;
  final String name;
  final String unit;
  final int minStock;
  final int onHand;
  final String? imageUrl;
  final Category? category;

  bool get isOutOfStock => onHand <= 0;
  bool get isLowStock => onHand <= minStock;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    sku: json['sku'] as String,
    barcode: json['barcode'] as String?,
    name: json['name'] as String,
    unit: json['unit'] as String,
    minStock: json['minStock'] as int,
    onHand: json['onHand'] as int,
    imageUrl: json['imageUrl'] as String?,
    category: json['category'] == null
        ? null
        : Category.fromJson(json['category'] as Map<String, dynamic>),
  );
}

class Paged<T> {
  const Paged({required this.items, required this.total, required this.page});

  final List<T> items;
  final int total;
  final int page;
}
