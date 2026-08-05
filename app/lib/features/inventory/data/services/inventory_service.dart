import '../../../../core/network/api_client.dart';
import '../models/inventory_model.dart';

class InventoryService {
  final _dio = ApiClient.instance.dio;

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Category>> categories() async {
    try {
      final res = await _dio.get(
        '/inventory/categories/',
        queryParameters: {'page_size': 200},
      );
      return _parseList(res.data, Category.fromJson);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Category> createCategory(Category category) async {
    try {
      final res = await _dio.post(
        '/inventory/categories/',
        data: category.toJson(),
      );
      return Category.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Category> updateCategory(int id, Category category) async {
    try {
      final res = await _dio.patch(
        '/inventory/categories/$id/',
        data: category.toJson(),
      );
      return Category.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _dio.delete('/inventory/categories/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  // ── Units ─────────────────────────────────────────────────────────────────

  Future<List<Unit>> units() async {
    try {
      final res = await _dio.get(
        '/inventory/units/',
        queryParameters: {'page_size': 200},
      );
      return _parseList(res.data, Unit.fromJson);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Unit> createUnit(Unit unit) async {
    try {
      final res = await _dio.post('/inventory/units/', data: unit.toJson());
      return Unit.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Unit> updateUnit(int id, Unit unit) async {
    try {
      final res = await _dio.patch(
        '/inventory/units/$id/',
        data: unit.toJson(),
      );
      return Unit.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteUnit(int id) async {
    try {
      await _dio.delete('/inventory/units/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  // ── Products / Services ───────────────────────────────────────────────────

  Future<List<Product>> products({
    String? search,
    int? categoryId,
    bool? lowStock,
    String? itemType, // PRODUCT | SERVICE | null = all
  }) async {
    try {
      final res = await _dio.get(
        '/inventory/products/',
        queryParameters: {
          'page_size': 500,
          if (search != null && search.isNotEmpty) 'search': search,
          if (categoryId != null) 'category': categoryId,
          if (lowStock == true) 'low_stock': 1,
          if (itemType != null && itemType.isNotEmpty) 'item_type': itemType,
        },
      );
      return _parseList(res.data, Product.fromJson);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Product> createProduct(Product product) async {
    try {
      final res = await _dio.post(
        '/inventory/products/',
        data: product.toJson(), // includes item_type
      );
      return Product.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Product> updateProduct(int id, Product product) async {
    try {
      final res = await _dio.patch(
        '/inventory/products/$id/',
        data: product.toJson(),
      );
      return Product.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _dio.delete('/inventory/products/$id/');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Map<String, dynamic>> bulkImport(
    List<Map<String, dynamic>> products,
  ) async {
    try {
      final res = await _dio.post(
        '/inventory/products/bulk-import/',
        data: {'products': products},
      );
      return _asMap(res.data);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  // ── Stock movements ───────────────────────────────────────────────────────

  Future<List<StockMovement>> stockMovements({int? productId}) async {
    try {
      final res = await _dio.get(
        '/inventory/stock-movements/',
        queryParameters: {
          'page_size': 200,
          if (productId != null) 'product': productId,
        },
      );
      return _parseList(res.data, StockMovement.fromJson);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<StockMovement> createStockMovement(StockMovement movement) async {
    try {
      final res = await _dio.post(
        '/inventory/stock-movements/',
        data: movement.toJson(),
      );
      return StockMovement.fromJson(_asMap(res.data));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    throw ApiException('Unexpected response format');
  }

  static List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = data is Map
        ? (data['results'] as List? ?? const [])
        : (data is List ? data : const []);
    return raw
        .whereType<Map>()
        .map((e) => fromJson(
              e is Map<String, dynamic>
                  ? e
                  : e.map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }
}