import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/inventory_model.dart';
import '../../domain/usecases/inventory_usecases.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryUseCases _useCases;

  InventoryProvider([InventoryUseCases? useCases])
      : _useCases = useCases ?? InventoryUseCases();

  List<Product> products = [];
  List<Category> categories = [];
  List<Unit> units = [];
  bool isLoading = false;
  String? error;

  /// Active list filter (null = all).
  String? filterItemType; // PRODUCT | SERVICE | null
  String? filterSearch;
  int? filterCategoryId;
  bool filterLowStock = false;

  Future<void> load({
    String? search,
    int? categoryId,
    bool? lowStock,
    String? itemType,
  }) async {
    filterSearch = search ?? filterSearch;
    filterCategoryId = categoryId ?? filterCategoryId;
    filterLowStock = lowStock ?? filterLowStock;
    filterItemType = itemType ?? filterItemType;

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _useCases.listProducts(
          search: filterSearch,
          categoryId: filterCategoryId,
          lowStock: filterLowStock ? true : null,
          itemType: filterItemType,
        ),
        _useCases.listCategories(),
        _useCases.listUnits(),
      ]);
      products = results[0] as List<Product>;
      categories = results[1] as List<Category>;
      units = results[2] as List<Unit>;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setItemTypeFilter(String? type) async {
    filterItemType = type;
    await load();
  }

  List<Product> get productItems =>
      products.where((p) => p.isProduct).toList();

  List<Product> get serviceItems =>
      products.where((p) => p.isService).toList();

  List<Product> get lowStock =>
      products.where((p) => p.isProduct && p.isLowStock).toList();

  Future<bool> saveProduct(Product product, {int? id}) {
    return _guard(() async {
      if (id != null) {
        final updated = await _useCases.saveProduct(product, id: id);
        products = [
          for (final p in products)
            if (p.id == id) updated else p,
        ];
      } else {
        final created = await _useCases.saveProduct(product);
        products = [created, ...products];
      }
      return true;
    });
  }

  /// Returns created product (for Quick POS / inline pickers).
  Future<Product?> quickCreate(Product product) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final created = await _useCases.saveProduct(product);
      products = [created, ...products];
      return created;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteProduct(int id) {
    return _guard(() async {
      await _useCases.deleteProduct(id);
      products = products.where((p) => p.id != id).toList();
      return true;
    });
  }

  Future<bool> saveCategory(Category category, {int? id}) {
    return _guard(() async {
      if (id != null) {
        final updated = await _useCases.saveCategory(category, id: id);
        categories = [
          for (final c in categories)
            if (c.id == id) updated else c,
        ];
      } else {
        final created = await _useCases.saveCategory(category);
        categories = [...categories, created];
      }
      return true;
    });
  }

  /// Create category and return it (for form "+ Add category").
  Future<Category?> quickCreateCategory(Category category) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final created = await _useCases.saveCategory(category);
      categories = [...categories, created];
      return created;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCategory(int id) {
    return _guard(() async {
      await _useCases.deleteCategory(id);
      categories = categories.where((c) => c.id != id).toList();
      return true;
    });
  }

  Future<bool> saveUnit(Unit unit, {int? id}) {
    return _guard(() async {
      if (id != null) {
        final updated = await _useCases.saveUnit(unit, id: id);
        units = [
          for (final u in units)
            if (u.id == id) updated else u,
        ];
      } else {
        final created = await _useCases.saveUnit(unit);
        units = [...units, created];
      }
      return true;
    });
  }

  /// Create unit and return it (for form "+ Add unit").
  Future<Unit?> quickCreateUnit(Unit unit) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final created = await _useCases.saveUnit(unit);
      units = [...units, created];
      return created;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUnit(int id) {
    return _guard(() async {
      await _useCases.deleteUnit(id);
      units = units.where((u) => u.id != id).toList();
      return true;
    });
  }

  Future<bool> adjustStock(StockMovement movement) {
    return _guard(() async {
      await _useCases.adjustStock(movement);
      await load();
      return true;
    });
  }

  Future<bool> _guard(Future<bool> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}