import '../../data/models/inventory_model.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../repositories/inventory_repository.dart';

/// Domain use-cases for inventory.
/// Presentation (provider) calls this layer — not the service directly.
class InventoryUseCases {
  final InventoryRepository _repository;

  InventoryUseCases([InventoryRepository? repository])
      : _repository = repository ?? InventoryRepositoryImpl();

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Category>> listCategories() => _repository.categories();

  Future<Category> saveCategory(Category category, {int? id}) {
    return id != null
        ? _repository.updateCategory(id, category)
        : _repository.createCategory(category);
  }

  Future<void> deleteCategory(int id) => _repository.deleteCategory(id);

  // ── Units ─────────────────────────────────────────────────────────────────

  Future<List<Unit>> listUnits() => _repository.units();

  Future<Unit> saveUnit(Unit unit, {int? id}) {
    return id != null
        ? _repository.updateUnit(id, unit)
        : _repository.createUnit(unit);
  }

  Future<void> deleteUnit(int id) => _repository.deleteUnit(id);

  // ── Products / Services ───────────────────────────────────────────────────

  Future<List<Product>> listProducts({
    String? search,
    int? categoryId,
    bool? lowStock,
    String? itemType, // PRODUCT | SERVICE | null = all
  }) {
    return _repository.products(
      search: search,
      categoryId: categoryId,
      lowStock: lowStock,
      itemType: itemType,
    );
  }

  Future<Product> saveProduct(Product product, {int? id}) {
    return id != null
        ? _repository.updateProduct(id, product)
        : _repository.createProduct(product);
  }

  Future<void> deleteProduct(int id) => _repository.deleteProduct(id);

  Future<Map<String, dynamic>> bulkImportProducts(
    List<Map<String, dynamic>> products,
  ) {
    return _repository.bulkImportProducts(products);
  }

  // ── Stock movements ───────────────────────────────────────────────────────

  Future<List<StockMovement>> listStockMovements({int? productId}) {
    return _repository.stockMovements(productId: productId);
  }

  Future<StockMovement> adjustStock(StockMovement movement) {
    return _repository.createStockMovement(movement);
  }
}