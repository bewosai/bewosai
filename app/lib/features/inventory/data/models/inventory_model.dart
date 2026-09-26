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

  /// Suggested price for a billing line when its unit is switched between
  /// this Unit's primary and secondary unit — dividing `basePrice` (the
  /// product's sale_price/purchase_price, priced per primary unit) by
  /// conversion_factor gives the per-secondary-unit price. Picking the
  /// primary unit (or anything else) just returns basePrice unchanged.
  /// Mirrors the backend's Unit.base_quantity_for — this is the price-side
  /// counterpart, purely a UI starting point the user can still edit.
  ///
  /// [secondaryPrice] is the product's own price for the secondary unit
  /// (secondarySalePrice / secondaryPurchasePrice); when set it wins over the
  /// divided price.
  double priceFor(double basePrice, String unitLabel, {double? secondaryPrice}) {
    if (unitLabel.isNotEmpty &&
        secondaryUnit.isNotEmpty &&
        conversionFactor != null &&
        conversionFactor! > 0 &&
        unitLabel.trim().toLowerCase() == secondaryUnit.trim().toLowerCase()) {
      if (secondaryPrice != null && secondaryPrice > 0) return secondaryPrice;
      return ((basePrice / conversionFactor!) * 100).round() / 100;
    }
    return basePrice;
  }

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
  /// Full primary/secondary/conversion_factor detail, so billing screens can
  /// offer a per-line unit picker without a separate Units lookup. Null
  /// when the product has no unit set.
  final Unit? unitDetail;
  final String description;
  final double purchasePrice;
  final double salePrice;
  /// Own prices per *secondary* unit (e.g. per Piece of a 12-Piece Box).
  /// Null = work it out as the main price ÷ conversion factor.
  final double? secondaryPurchasePrice;
  final double? secondarySalePrice;
  /// Opening / current stock (PRODUCT only; 0 for SERVICE).
  final double stockQuantity;
  final double lowStockThreshold;
  final bool isLowStock;
  final String barcode;
  /// Harmonized System code — Nepal customs/VAT classification, shown on
  /// some tax invoices. Optional.
  final String hsCode;
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
    this.unitDetail,
    required this.description,
    required this.purchasePrice,
    required this.salePrice,
    this.secondaryPurchasePrice,
    this.secondarySalePrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.isLowStock,
    required this.barcode,
    this.hsCode = '',
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
      unitDetail: json['unit_detail'] == null
          ? null
          : Unit.fromJson(json['unit_detail'] as Map<String, dynamic>),
      description: json['description']?.toString() ?? '',
      purchasePrice: Formatters.toDouble(json['purchase_price']),
      salePrice: Formatters.toDouble(json['sale_price']),
      secondaryPurchasePrice: json['secondary_purchase_price'] == null
          ? null
          : Formatters.toDouble(json['secondary_purchase_price']),
      secondarySalePrice: json['secondary_sale_price'] == null
          ? null
          : Formatters.toDouble(json['secondary_sale_price']),
      stockQuantity: Formatters.toDouble(json['stock_quantity']),
      lowStockThreshold: Formatters.toDouble(json['low_stock_threshold']),
      isLowStock: json['is_low_stock'] == true ||
          json['is_low_stock']?.toString().toLowerCase() == 'true',
      barcode: json['barcode']?.toString() ?? '',
      hsCode: json['hs_code']?.toString() ?? '',
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
      'secondary_purchase_price': secondaryPurchasePrice,
      'secondary_sale_price': secondarySalePrice,
      'stock_quantity': isSvc ? 0 : stockQuantity,
      'low_stock_threshold': isSvc ? 0 : lowStockThreshold,
      'barcode': barcode,
      'hs_code': hsCode,
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
        // Unit.toJson() is a write-payload for the Units API (no id/display)
        // — reconstructed by hand here so Unit.fromJson round-trips fully.
        if (unitDetail != null)
          'unit_detail': {
            'id': unitDetail!.id,
            'name': unitDetail!.name,
            'abbreviation': unitDetail!.abbreviation,
            'secondary_unit': unitDetail!.secondaryUnit,
            'secondary_abbreviation': unitDetail!.secondaryAbbreviation,
            'conversion_factor': unitDetail!.conversionFactor,
            'display': unitDetail!.display,
          },
        'description': description,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'secondary_purchase_price': secondaryPurchasePrice,
        'secondary_sale_price': secondarySalePrice,
        'stock_quantity': stockQuantity,
        'low_stock_threshold': lowStockThreshold,
        'is_low_stock': isLowStock,
        'barcode': barcode,
        'hs_code': hsCode,
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
    Unit? unitDetail,
    String? description,
    double? purchasePrice,
    double? salePrice,
    double? secondaryPurchasePrice,
    double? secondarySalePrice,
    double? stockQuantity,
    double? lowStockThreshold,
    bool? isLowStock,
    String? barcode,
    String? hsCode,
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
      unitDetail: clearUnit ? null : (unitDetail ?? this.unitDetail),
      description: description ?? this.description,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      secondaryPurchasePrice: secondaryPurchasePrice ?? this.secondaryPurchasePrice,
      secondarySalePrice: secondarySalePrice ?? this.secondarySalePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isLowStock: isLowStock ?? this.isLowStock,
      barcode: barcode ?? this.barcode,
      hsCode: hsCode ?? this.hsCode,
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