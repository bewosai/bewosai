import '../../domain/repositories/inventory_repository.dart';
import '../models/inventory_model.dart';
import '../services/inventory_service.dart';

/// Data-layer implementation of [InventoryRepository].
/// Thin pass-through to [InventoryService] — no business logic.
class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryService _service;

  InventoryRepositoryImpl([InventoryService? service])
      : _service = service ?? InventoryService();

  // ── Categories ────────────────────────────────────────────────────────────

  @override
  Future<List<Category>> categories() => _service.categories();

  @override
  Future<Category> createCategory(Category category) =>
      _service.createCategory(category);

  @override
  Future<Category> updateCategory(int id, Category category) =>
      _service.updateCategory(id, category);

  @override
  Future<void> deleteCategory(int id) => _service.deleteCategory(id);

  // ── Units ─────────────────────────────────────────────────────────────────

  @override
  Future<List<Unit>> units() => _service.units();

  @override
  Future<Unit> createUnit(Unit unit) => _service.createUnit(unit);

  @override
  Future<Unit> updateUnit(int id, Unit unit) =>
      _service.updateUnit(id, unit);

  @override
  Future<void> deleteUnit(int id) => _service.deleteUnit(id);

  // ── Products / Services ───────────────────────────────────────────────────

  @override
  Future<List<Product>> products({
    String? search,
    int? categoryId,
    bool? lowStock,
    String? itemType, // PRODUCT | SERVICE | null = all
  }) {
    return _service.products(
      search: search,
      categoryId: categoryId,
      lowStock: lowStock,
      itemType: itemType,
    );
  }

  @override
  Future<Product> createProduct(Product product) =>
      _service.createProduct(product);

  @override
  Future<Product> updateProduct(int id, Product product) =>
      _service.updateProduct(id, product);

  @override
  Future<void> deleteProduct(int id) => _service.deleteProduct(id);

  @override
  Future<Map<String, dynamic>> bulkImportProducts(
    List<Map<String, dynamic>> products,
  ) {
    return _service.bulkImport(products);
  }

  // ── Stock movements ───────────────────────────────────────────────────────

  @override
  Future<List<StockMovement>> stockMovements({int? productId}) {
    return _service.stockMovements(productId: productId);
  }

  @override
  Future<StockMovement> createStockMovement(StockMovement movement) {
    return _service.createStockMovement(movement);
  }
}