import '../../data/models/inventory_model.dart';

/// Domain contract for inventory (categories, units, products, stock).
/// Implemented by [InventoryRepositoryImpl] → [InventoryService].
abstract class InventoryRepository {
  // Categories
  Future<List<Category>> categories();
  Future<Category> createCategory(Category category);
  Future<Category> updateCategory(int id, Category category);
  Future<void> deleteCategory(int id);

  // Units
  Future<List<Unit>> units();
  Future<Unit> createUnit(Unit unit);
  Future<Unit> updateUnit(int id, Unit unit);
  Future<void> deleteUnit(int id);

  // Products / Services
  Future<List<Product>> products({
    String? search,
    int? categoryId,
    bool? lowStock,
    String? itemType, // PRODUCT | SERVICE | null = all
  });
  Future<Product> createProduct(Product product);
  Future<Product> updateProduct(int id, Product product);
  Future<void> deleteProduct(int id);
  Future<Map<String, dynamic>> bulkImportProducts(
    List<Map<String, dynamic>> products,
  );

  // Stock movements
  Future<List<StockMovement>> stockMovements({int? productId});
  Future<StockMovement> createStockMovement(StockMovement movement);
}