import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../providers/business_provider.dart';
import '../../widgets/app_widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _products = [];
  List _categories = [];
  List _units = [];
  bool _loading = true;
  String _search = '';
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final biz = context.read<BusinessProvider>();
    try {
      final results = await Future.wait([
        biz.getProducts(),
        biz.getCategories(),
        biz.getUnits(),
      ]);
      _products = results[0];
      _categories = results[1];
      _units = results[2];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List get _filteredProducts {
    var list = _products;
    if (_selectedCategory != 'ALL') {
      list = list
          .where((p) => p['category_name'] == _selectedCategory)
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((p) =>
              (p['name'] ?? '').toString().toLowerCase().contains(q) ||
              (p['barcode'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final catNames = ['ALL', ..._categories.map((c) => c['name'] as String)];

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('inventory'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.navy500,
          indicatorColor: AppColors.orange,
          tabs: [
            Tab(text: settings.t('products')),
            Tab(text: settings.t('category')),
            Tab(text: settings.t('units')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_fab',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showAddProductSheet(context, settings),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                // Products tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: settings.t('search'),
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    // Category filter
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: catNames.length,
                        itemBuilder: (ctx, i) {
                          final cat = catNames[i];
                          final sel = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: sel,
                              onSelected: (_) => setState(
                                  () => _selectedCategory = cat),
                              selectedColor:
                                  AppColors.orange.withOpacity(0.15),
                              labelStyle: TextStyle(
                                color: sel
                                    ? AppColors.orange
                                    : AppColors.navy500,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _filteredProducts.isEmpty
                          ? EmptyState(
                              icon: Icons.inventory_2_rounded,
                              message: settings.t('no_data'),
                            )
                          : RefreshIndicator(
                              onRefresh: () async => _fetch(),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (ctx, i) {
                                  final p = _filteredProducts[i];
                                  final stock = double.tryParse(
                                          p['stock_quantity']
                                                  ?.toString() ??
                                              '0') ??
                                      0;
                                  final minStock = double.tryParse(
                                          p['low_stock_threshold']
                                                  ?.toString() ??
                                              '0') ??
                                      0;
                                  final isLowStock =
                                      p['is_low_stock'] == true || (minStock > 0 && stock <= minStock);

                                  return AppCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.orange
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                            Icons.inventory_2_rounded,
                                            color: AppColors.orange,
                                            size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p['name'] ?? '—',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(children: [
                                              if (p['category_name'] !=
                                                  null)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.navy50,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(8),
                                                  ),
                                                  child: Text(
                                                      p['category_name'],
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: AppColors
                                                              .navy500)),
                                                ),
                                              const SizedBox(width: 6),
                                              if (isLowStock)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.errorLight,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(8),
                                                  ),
                                                  child: const Text(
                                                      'Low Stock',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              AppColors
                                                                  .error)),
                                                ),
                                            ]),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            settings.formatAmount(
                                                double.tryParse(
                                                        p['selling_price']
                                                                ?.toString() ??
                                                            p['sell_price']
                                                                ?.toString() ??
                                                            '0') ??
                                                    0),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: AppColors.orange),
                                          ),
                                          Text(
                                            'Stock: $stock ${p['unit_name'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isLowStock
                                                  ? AppColors.error
                                                  : AppColors.navy500,
                                              fontWeight: isLowStock
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: () => _showStockAdjust(
                                                context,
                                                Map<String, dynamic>.from(p as Map)),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.info.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                                Icon(Icons.tune_rounded,
                                                    size: 12, color: AppColors.info),
                                                SizedBox(width: 4),
                                                Text('Adjust',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors.info,
                                                        fontWeight: FontWeight.w600)),
                                              ]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ]),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
                // Categories tab
                _categories.isEmpty
                    ? EmptyState(
                        icon: Icons.category_rounded,
                        message: settings.t('no_data'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _categories.length,
                        itemBuilder: (ctx, i) {
                          final c = _categories[i];
                          return AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.category_rounded,
                                    color: AppColors.orange, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(c['name'] ?? '—',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                              ),
                              Text('${c['product_count'] ?? 0} products',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.navy500)),
                            ]),
                          );
                        },
                      ),
                // Units tab
                _units.isEmpty
                    ? EmptyState(
                        icon: Icons.straighten_rounded,
                        message: settings.t('no_data'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _units.length,
                        itemBuilder: (ctx, i) {
                          final u = _units[i];
                          return AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.straighten_rounded,
                                    color: AppColors.info, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(u['name'] ?? '—',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    if (u['secondary_name'] != null)
                                      Text(
                                          '1 ${u['name']} = ${u['conversion_rate']} ${u['secondary_name']}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.navy500)),
                                  ],
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
              ],
            ),
    );
  }

  void _showAddProductSheet(BuildContext context, AppSettings settings) {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final buyPriceCtrl = TextEditingController();
    final sellPriceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final minStockCtrl = TextEditingController(text: '0');
    bool saving = false;
    String? selectedUnit;
    String? selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (_, ctrl) => ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Add Product',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Product Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skuCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Barcode / Code'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: buyPriceCtrl,
                      decoration: InputDecoration(
                          labelText: settings.t('buy_price')),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: sellPriceCtrl,
                      decoration: InputDecoration(
                          labelText: settings.t('sell_price')),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      decoration: InputDecoration(
                          labelText: settings.t('stock')),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: minStockCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Min Stock Alert'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                if (_units.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration:
                        InputDecoration(labelText: settings.t('units')),
                    items: _units
                        .map((u) => DropdownMenuItem<String>(
                            value: u['id'].toString(),
                            child: Text(u['name'])))
                        .toList(),
                    onChanged: (v) => ss(() => selectedUnit = v),
                  ),
                ],
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                        labelText: settings.t('category')),
                    items: _categories
                        .map((c) => DropdownMenuItem<String>(
                            value: c['id'].toString(),
                            child: Text(c['name'])))
                        .toList(),
                    onChanged: (v) => ss(() => selectedCategory = v),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: settings.t('save'),
                  loading: saving,
                  onPressed: saving
                      ? null
                      : () async {
                          ss(() => saving = true);
                          try {
                            await context.read<ApiService>().post(
                              '/inventory/products/',
                              data: {
                                'name': nameCtrl.text.trim(),
                                'barcode': skuCtrl.text.trim(),
                                'purchase_price': double.tryParse(
                                        buyPriceCtrl.text) ??
                                    0,
                                'sale_price': double.tryParse(
                                        sellPriceCtrl.text) ??
                                    0,
                                'stock_quantity':
                                    double.tryParse(stockCtrl.text) ?? 0,
                                'low_stock_threshold':
                                    double.tryParse(minStockCtrl.text) ??
                                        0,
                                if (selectedUnit != null)
                                  'unit': selectedUnit,
                                if (selectedCategory != null)
                                  'category': selectedCategory,
                              },
                            );
                            if (context.mounted) {
                              Navigator.pop(ctx2);
                              _fetch();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ApiService.errorMessage(e))));
                            }
                          }
                          ss(() => saving = false);
                        },
                  icon: Icons.check_rounded,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStockAdjust(BuildContext ctx2, Map<String, dynamic> product) {
    final api = context.read<ApiService>();
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String movementType = 'ADJUSTMENT';
    bool saving = false;

    final currentStock = product['stock_quantity']?.toString() ?? '0';

    const types = [
      ('IN', 'Stock In', Icons.add_circle_outline_rounded, AppColors.success),
      ('OPENING', 'Opening', Icons.inventory_rounded, AppColors.info),
      ('ADJUSTMENT', 'Adjust', Icons.tune_rounded, AppColors.warning),
      ('DAMAGE', 'Damage', Icons.broken_image_rounded, AppColors.error),
      ('LOST', 'Lost', Icons.help_outline_rounded, AppColors.error),
      ('OUT', 'Manual Out', Icons.remove_circle_outline_rounded, AppColors.navy500),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx3, ss) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx3).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stock Adjustment',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(product['name']?.toString() ?? '',
                            style: const TextStyle(
                                color: AppColors.navy500, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Stock: $currentStock',
                        style: const TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 16),
                // Type grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: types.map((t) {
                    final selected = movementType == t.$1;
                    return GestureDetector(
                      onTap: () => ss(() => movementType = t.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? t.$4
                              : t.$4.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? t.$4
                                : t.$4.withOpacity(0.3),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(t.$3,
                              size: 14,
                              color: selected ? Colors.white : t.$4),
                          const SizedBox(width: 6),
                          Text(t.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : t.$4,
                              )),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'Enter quantity',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Reason / Notes'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: saving ? 'Saving...' : 'Apply Adjustment',
                  loading: saving,
                  icon: Icons.check_rounded,
                  onPressed: saving
                      ? null
                      : () async {
                          final qty = double.tryParse(qtyCtrl.text.trim());
                          if (qty == null || qty <= 0) return;
                          ss(() => saving = true);
                          try {
                            await api.post(
                              '/inventory/stock-movements/',
                              data: {
                                'product': product['id'],
                                'movement_type': movementType,
                                'quantity': qty,
                                'note': notesCtrl.text.trim(),
                              },
                            );
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              _fetch();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Stock updated!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ApiService.errorMessage(e))));
                            }
                          }
                          ss(() => saving = false);
                        },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
