import '../../../../core/utils/formatters.dart';

// ── Category ──────────────────────────────────────────────────────────────────

class Category {
  final int id;
  final String name;
  final String description;

  const Category({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };

  Category copyWith({int? id, String? name, String? description}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Unit ──────────────────────────────────────────────────────────────────────

class Unit {
  final int id;
  final String name;
  final String abbreviation;
  final String secondaryUnit;
  final String secondaryAbbreviation;
  final double? conversionFactor;
  final String display;

  const Unit({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.secondaryUnit,
    required this.secondaryAbbreviation,
    this.conversionFactor,
    required this.display,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return Unit(
      id: _toInt(json['id']),
      name: name,
      abbreviation: json['abbreviation']?.toString() ?? '',
      secondaryUnit: json['secondary_unit']?.toString() ?? '',
      secondaryAbbreviation:
          json['secondary_abbreviation']?.toString() ?? '',
      conversionFactor: json['conversion_factor'] == null
          ? null
          : Formatters.toDouble(json['conversion_factor']),
      display: json['display']?.toString() ?? name,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'abbreviation': abbreviation,
        if (secondaryUnit.isNotEmpty) 'secondary_unit': secondaryUnit,
        if (secondaryAbbreviation.isNotEmpty)
          'secondary_abbreviation': secondaryAbbreviation,
        if (conversionFactor != null) 'conversion_factor': conversionFactor,
      };

  bool get hasSecondary => secondaryUnit.isNotEmpty;

  Unit copyWith({
    int? id,
    String? name,
    String? abbreviation,
    String? secondaryUnit,
    String? secondaryAbbreviation,
    double? conversionFactor,
    String? display,
  }) {
    return Unit(
      id: id ?? this.id,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      secondaryUnit: secondaryUnit ?? this.secondaryUnit,
      secondaryAbbreviation:
          secondaryAbbreviation ?? this.secondaryAbbreviation,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      display: display ?? this.display,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unit && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Item type ─────────────────────────────────────────────────────────────────

class ItemType {
  static const product = 'PRODUCT';
  static const service = 'SERVICE';
  static const labels = {
    product: 'Product',
    service: 'Service',
  };
  static const all = [product, service];
}

// ── Product / Service ─────────────────────────────────────────────────────────

class Product {
  final int id;
  final String name;
  final int? category;
  final String categoryName;
  /// PRODUCT | SERVICE
  final String itemType;
  final int? unit;
  final String unitName;
  final String description;
  final double purchasePrice;
  final double salePrice;
  /// Opening / current stock (PRODUCT only; 0 for SERVICE).
  final double stockQuantity;
  final double lowStockThreshold;
  final bool isLowStock;
  final String barcode;
  final String? image;
  final bool isActive;
  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.name,
    this.category,
    required this.categoryName,
    this.itemType = ItemType.product,
    this.unit,
    required this.unitName,
    required this.description,
    required this.purchasePrice,
    required this.salePrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.isLowStock,
    required this.barcode,
    this.image,
    required this.isActive,
    this.createdAt,
  });

  bool get isProduct => itemType == ItemType.product;
  bool get isService => itemType == ItemType.service;

  factory Product.fromJson(Map<String, dynamic> json) {
    final type =
        (json['item_type']?.toString() ?? ItemType.product).toUpperCase();
    return Product(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      category: _toIntOrNull(json['category']),
      categoryName: json['category_name']?.toString() ?? '',
      itemType:
          type == ItemType.service ? ItemType.service : ItemType.product,
      unit: _toIntOrNull(json['unit']),
      unitName: json['unit_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      purchasePrice: Formatters.toDouble(json['purchase_price']),
      salePrice: Formatters.toDouble(json['sale_price']),
      stockQuantity: Formatters.toDouble(json['stock_quantity']),
      lowStockThreshold: Formatters.toDouble(json['low_stock_threshold']),
      isLowStock: json['is_low_stock'] == true ||
          json['is_low_stock']?.toString().toLowerCase() == 'true',
      barcode: json['barcode']?.toString() ?? '',
      image: json['image']?.toString(),
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] == true ||
              json['is_active']?.toString().toLowerCase() == 'true'),
      createdAt: Formatters.parseDate(json['created_at']?.toString()),
    );
  }

  /// Write body. Service → stock fields sent as 0.
  Map<String, dynamic> toJson() {
    final isSvc = itemType == ItemType.service;
    return {
      'name': name,
      'item_type': itemType,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      'description': description,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'stock_quantity': isSvc ? 0 : stockQuantity,
      'low_stock_threshold': isSvc ? 0 : lowStockThreshold,
      'barcode': barcode,
      'is_active': isActive,
    };
  }

  /// Full read-shape serialization (unlike [toJson], which is a write body
  /// missing server-computed fields) — used to persist this product to the
  /// offline cache so [Product.fromJson] can reconstruct it byte-for-byte.
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'category': category,
        'category_name': categoryName,
        'item_type': itemType,
        'unit': unit,
        'unit_name': unitName,
        'description': description,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'stock_quantity': stockQuantity,
        'low_stock_threshold': lowStockThreshold,
        'is_low_stock': isLowStock,
        'barcode': barcode,
        'image': image,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };

  Product copyWith({
    int? id,
    String? name,
    int? category,
    String? categoryName,
    String? itemType,
    int? unit,
    String? unitName,
    String? description,
    double? purchasePrice,
    double? salePrice,
    double? stockQuantity,
    double? lowStockThreshold,
    bool? isLowStock,
    String? barcode,
    String? image,
    bool? isActive,
    DateTime? createdAt,
    bool clearCategory = false,
    bool clearUnit = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: clearCategory ? null : (category ?? this.category),
      categoryName: categoryName ?? this.categoryName,
      itemType: itemType ?? this.itemType,
      unit: clearUnit ? null : (unit ?? this.unit),
      unitName: unitName ?? this.unitName,
      description: description ?? this.description,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isLowStock: isLowStock ?? this.isLowStock,
      barcode: barcode ?? this.barcode,
      image: image ?? this.image,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Stock movement ────────────────────────────────────────────────────────────

class StockMovement {
  final int id;
  final int product;
  final String productName;
  final String movementType;
  final double quantity;
  final String note;
  final String createdByName;
  final DateTime? createdAt;

  const StockMovement({
    required this.id,
    required this.product,
    required this.productName,
    required this.movementType,
    required this.quantity,
    required this.note,
    required this.createdByName,
    this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: _toInt(json['id']),
      product: _toInt(json['product']),
      productName: json['product_name']?.toString() ?? '',
      movementType: json['movement_type']?.toString() ?? 'IN',
      quantity: Formatters.toDouble(json['quantity']),
      note: json['note']?.toString() ?? '',
      createdByName: json['created_by_name']?.toString() ?? '',
      createdAt: Formatters.parseDate(json['created_at']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'product': product,
        'movement_type': movementType,
        'quantity': quantity,
        'note': note,
      };

  StockMovement copyWith({
    int? id,
    int? product,
    String? productName,
    String? movementType,
    double? quantity,
    String? note,
    String? createdByName,
    DateTime? createdAt,
  }) {
    return StockMovement(
      id: id ?? this.id,
      product: product ?? this.product,
      productName: productName ?? this.productName,
      movementType: movementType ?? this.movementType,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Safe parsers ──────────────────────────────────────────────────────────────

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return int.tryParse(v.toString()) ?? 0;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) {
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }
  return int.tryParse(v.toString());
}