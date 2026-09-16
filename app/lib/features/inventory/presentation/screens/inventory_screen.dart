import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/excel_import_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/models/inventory_model.dart';
import '../providers/inventory_provider.dart';
import 'inventory_import_screen.dart';

// Same column order as InventoryImportScreen's template, so an exported
// file can be edited and re-imported unchanged.
const _kExportHeaders = [
  'name', 'category', 'unit', 'sale_price', 'purchase_price',
  'stock_quantity', 'low_stock_threshold', 'barcode', 'hs_code', 'description',
];

Future<void> _exportProducts(BuildContext context, List<Product> products) async {
  try {
    final path = await ExcelImportUtils.writeRows(
      sheetName: 'Products',
      headers: _kExportHeaders,
      rows: [
        for (final p in products)
          [
            p.name, p.categoryName, p.unitName,
            p.salePrice.toString(), p.purchasePrice.toString(),
            p.stockQuantity.toString(), p.lowStockThreshold.toString(),
            p.barcode, p.hsCode, p.description,
          ],
      ],
      fileName: 'bewosai_products_export.xlsx',
    );
    if (!context.mounted) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Bewosai products export'));
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'Could not create the export file', isError: true);
    }
  }
}

class InventoryScreen extends StatefulWidget {
  final bool initialLowStockFilter;
  final bool openAddOnStart;
  const InventoryScreen({
    super.key,
    this.initialLowStockFilter = false,
    this.openAddOnStart = false,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();
    _lowStockOnly = widget.initialLowStockFilter;
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<InventoryProvider>().load();
      if (widget.openAddOnStart && mounted) _openProductModal(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final kpiColumns = width < 420 ? 2 : (width < 800 ? 2 : 4);

    // No AppBar/bottom-nav when this is the embedded "Inventory" bottom-nav
    // tab (MainShell provides chrome there), but it's also pushed standalone
    // for the low-stock filter AND the Dashboard's "Add Item" shortcut —
    // both need a title, back button, and way home just like every other
    // standalone-pushed screen.
    final standalone = widget.initialLowStockFilter || widget.openAddOnStart;
    return Scaffold(
      appBar: standalone
          ? AppBar(
              title: Text(widget.initialLowStockFilter ? 'Low Stock Products' : 'Inventory'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.upload_file_outlined),
                  tooltip: 'Import Products',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InventoryImportScreen()),
                  ),
                ),
                const HomeLogoButton(),
              ],
            )
          : null,
      bottomNavigationBar: standalone
          ? const AppBottomNav(currentIndex: 3)
          : null,
      floatingActionButton: FloatingActionButton(
        heroTag: 'inventory_fab',
        onPressed: () {
          switch (_tabController.index) {
            case 0:
              _openProductModal(context);
              break;
            case 1:
              _openUnitModal(context);
              break;
            case 2:
              _openCategoryModal(context);
              break;
          }
        },
        child: const Icon(Icons.add),
      ),
      body: ResponsiveBody(
        child: inv.isLoading && inv.products.isEmpty
            ? const LoadingView()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ResponsiveGrid(
                      columns: kpiColumns,
                      spacing: 10,
                      childAspectRatio: 0.75,
                      children: [
                        KpiCard(
                          label: 'Products',
                          value: '${inv.products.length}',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.orange,
                        ),
                        KpiCard(
                          label: 'Low Stock',
                          value: '${inv.lowStock.length}',
                          icon: Icons.warning_amber_rounded,
                          color: inv.lowStock.isNotEmpty
                              ? AppColors.warning
                              : AppColors.navy300,
                          onTap: () => setState(() => _lowStockOnly = true),
                        ),
                        KpiCard(
                          label: 'Categories',
                          value: '${inv.categories.length}',
                          icon: Icons.category_outlined,
                          color: AppColors.info,
                        ),
                        KpiCard(
                          label: 'Units',
                          value: '${inv.units.length}',
                          icon: Icons.straighten_outlined,
                          color: AppColors.navy600,
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.orange,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.orange,
                    onTap: (_) => setState(() {}),
                    tabs: const [
                      Tab(text: 'Products'),
                      Tab(text: 'Units'),
                      Tab(text: 'Categories'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _ProductsTab(
                          search: _search,
                          lowStockOnly: _lowStockOnly,
                          onSearch: (v) => setState(() => _search = v),
                          onClearLowStock: () =>
                              setState(() => _lowStockOnly = false),
                          onEdit: (p) => _openProductModal(context, product: p),
                        ),
                        _UnitsTab(
                          onEdit: (u) => _openUnitModal(context, unit: u),
                        ),
                        _CategoriesTab(
                          onEdit: (c) =>
                              _openCategoryModal(context, category: c),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openProductModal(BuildContext context, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductFormSheet(product: product),
    );
  }

  void _openUnitModal(BuildContext context, {Unit? unit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UnitFormSheet(unit: unit),
    );
  }

  void _openCategoryModal(BuildContext context, {Category? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryFormSheet(category: category),
    );
  }
}

class _ProductsTab extends StatelessWidget {
  final String search;
  final bool lowStockOnly;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearLowStock;
  final ValueChanged<Product> onEdit;

  const _ProductsTab({
    required this.search,
    required this.lowStockOnly,
    required this.onSearch,
    required this.onClearLowStock,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    var products = inv.products;
    if (lowStockOnly) products = products.where((p) => p.isLowStock).toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      products = products
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.barcode.toLowerCase().contains(q),
          )
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: SearchField(hint: 'Search products', onChanged: onSearch)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export Products',
              style: IconButton.styleFrom(backgroundColor: AppColors.surface, side: BorderSide(color: AppColors.divider)),
              onPressed: inv.products.isEmpty ? null : () => _exportProducts(context, inv.products),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Import Products',
              style: IconButton.styleFrom(backgroundColor: AppColors.surface, side: BorderSide(color: AppColors.divider)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InventoryImportScreen()),
              ),
            ),
          ],
        ),
        if (lowStockOnly) ...[
          const SizedBox(height: 10),
          AppFilterChip(
            label: 'Low Stock Only',
            selected: true,
            onTap: onClearLowStock,
          ),
        ],
        const SizedBox(height: 14),
        if (products.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products found',
          )
        else
          ...products.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => onEdit(p),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${p.categoryName.isEmpty ? 'Uncategorized' : p.categoryName} · ${p.unitName}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            if (p.isLowStock)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: StatusBadge(
                                  label: 'LOW',
                                  color: AppColors.error,
                                ),
                              ),
                            Text(
                              '${Formatters.amount(p.stockQuantity)} ${p.unitName}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          Formatters.currency(p.salePrice),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.tune,
                        size: 20,
                        color: AppColors.navy400,
                      ),
                      tooltip: 'Adjust stock',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _StockAdjustDialog(product: p),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.navy400,
                      ),
                      tooltip: 'Delete',
                      onPressed: () async {
                        final provider = context.read<InventoryProvider>();
                        final confirmed = await showDeleteConfirmDialog(
                          context,
                          message:
                              'Delete "${p.name}"? It will be moved to Recycle Bin.',
                        );
                        if (confirmed) provider.deleteProduct(p.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UnitsTab extends StatelessWidget {
  final ValueChanged<Unit> onEdit;
  const _UnitsTab({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<InventoryProvider>().units;
    if (units.isEmpty) {
      return const EmptyState(
        icon: Icons.straighten_outlined,
        title: 'No units yet',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: units
          .map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => onEdit(u),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${u.name}${u.abbreviation.isNotEmpty ? ' (${u.abbreviation})' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (u.hasSecondary)
                            Text(
                              '1 ${u.name} = ${Formatters.amount(u.conversionFactor)} ${u.secondaryUnit}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (u.hasSecondary) ...[
                      const StatusBadge(
                        label: 'Dual Unit',
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.navy400,
                      ),
                      tooltip: 'Delete',
                      onPressed: () async {
                        final provider = context.read<InventoryProvider>();
                        final confirmed = await showDeleteConfirmDialog(
                          context,
                          message:
                              'Delete unit "${u.name}"? Products using it will keep their stock but lose this unit label.',
                        );
                        if (confirmed) provider.deleteUnit(u.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  final ValueChanged<Category> onEdit;
  const _CategoriesTab({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<InventoryProvider>().categories;
    if (categories.isEmpty) {
      return const EmptyState(
        icon: Icons.category_outlined,
        title: 'No categories yet',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories
            .map(
              (c) => InputChip(
                label: Text(c.name),
                onPressed: () => onEdit(c),
                onDeleted: () async {
                  final provider = context.read<InventoryProvider>();
                  final confirmed = await showDeleteConfirmDialog(
                    context,
                    message:
                        'Delete category "${c.name}"? Products using it will keep their data but lose this category label.',
                  );
                  if (confirmed) provider.deleteCategory(c.id);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  final Product? product;
  const _ProductFormSheet({this.product});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

// Real category/unit ids are always positive, so this can never collide —
// used as the "+ Add New ..." option's value in the two dropdowns below.
const _addNewSentinel = -1;

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.product?.name ?? '',
  );
  late final _purchasePriceController = TextEditingController(
    text: widget.product?.purchasePrice.toString() ?? '0',
  );
  late final _salePriceController = TextEditingController(
    text: widget.product?.salePrice.toString() ?? '0',
  );
  late final _stockController = TextEditingController(
    text: widget.product?.stockQuantity.toString() ?? '0',
  );
  late final _thresholdController = TextEditingController(
    text: widget.product?.lowStockThreshold.toString() ?? '5',
  );
  late final _barcodeController = TextEditingController(
    text: widget.product?.barcode ?? '',
  );
  late final _hsCodeController = TextEditingController(
    text: widget.product?.hsCode ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.product?.description ?? '',
  );
  int? _category;
  int? _unit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.product?.category;
    _unit = widget.product?.unit;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final product = Product(
      id: widget.product?.id ?? 0,
      name: _nameController.text.trim(),
      category: _category,
      categoryName: '',
      unit: _unit,
      unitName: '',
      description: _descriptionController.text.trim(),
      purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
      salePrice: double.tryParse(_salePriceController.text) ?? 0,
      stockQuantity: double.tryParse(_stockController.text) ?? 0,
      lowStockThreshold: double.tryParse(_thresholdController.text) ?? 5,
      isLowStock: false,
      barcode: _barcodeController.text.trim(),
      hsCode: _hsCodeController.text.trim(),
      isActive: true,
    );
    final ok = await context.read<InventoryProvider>().saveProduct(
      product,
      id: widget.product?.id,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      final err = context.read<InventoryProvider>().error;
      showAppSnackBar(context, err ?? 'Failed to save product', isError: true);
    }
  }

  Future<void> _quickAddCategory() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add New Category'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Category Name *'),
              validator: (v) => Validators.required(v, 'Name'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            PrimaryButton(
              label: 'Save',
              expand: false,
              isLoading: saving,
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => saving = true);
                final invProvider = context.read<InventoryProvider>();
                final created = await invProvider.quickCreateCategory(
                  Category(id: 0, name: nameController.text.trim(), description: ''),
                );
                if (!dialogContext.mounted) return;
                if (created != null) {
                  setState(() => _category = created.id);
                  Navigator.pop(dialogContext);
                } else {
                  setDialogState(() => saving = false);
                  showAppSnackBar(
                    dialogContext,
                    invProvider.error ?? 'Failed to add category',
                    isError: true,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAddUnit() async {
    final nameController = TextEditingController();
    final abbrController = TextEditingController();
    final secondaryController = TextEditingController();
    final secondaryAbbrController = TextEditingController();
    final conversionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add New Unit'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: nameController,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: 'Unit Name *'),
                          validator: (v) => Validators.required(v, 'Name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: abbrController,
                          decoration: const InputDecoration(labelText: 'Abbreviation'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Secondary unit (optional, for dual-unit tracking)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: secondaryController,
                          decoration: const InputDecoration(labelText: 'Secondary Unit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: secondaryAbbrController,
                          decoration: const InputDecoration(labelText: 'Abbreviation'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: conversionController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Conversion factor (e.g. 1 Box = 12 Pieces)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            PrimaryButton(
              label: 'Save',
              expand: false,
              isLoading: saving,
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => saving = true);
                final invProvider = context.read<InventoryProvider>();
                final created = await invProvider.quickCreateUnit(
                  Unit(
                    id: 0,
                    name: nameController.text.trim(),
                    abbreviation: abbrController.text.trim(),
                    secondaryUnit: secondaryController.text.trim(),
                    secondaryAbbreviation: secondaryAbbrController.text.trim(),
                    conversionFactor: double.tryParse(conversionController.text),
                    display: '',
                  ),
                );
                if (!dialogContext.mounted) return;
                if (created != null) {
                  setState(() => _unit = created.id);
                  Navigator.pop(dialogContext);
                } else {
                  setDialogState(() => saving = false);
                  showAppSnackBar(
                    dialogContext,
                    invProvider.error ?? 'Failed to add unit',
                    isError: true,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _barcodeController.dispose();
    _hsCodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Live "= Rs. X / Piece" hint shown under a price field once a unit with
  /// a secondary unit is selected — the field itself is always entered in
  /// the *primary* unit (matching how Unit.priceFor/base_quantity_for treat
  /// it elsewhere), so this exists purely to save the shop owner from doing
  /// the box-to-piece division by hand and getting it wrong.
  String? _secondaryPriceHint(InventoryProvider inv, String priceText) {
    Unit? selectedUnit;
    for (final u in inv.units) {
      if (u.id == _unit) {
        selectedUnit = u;
        break;
      }
    }
    if (selectedUnit == null || !selectedUnit.hasSecondary) return null;
    final price = double.tryParse(priceText);
    if (price == null) return null;
    final secondaryPrice = selectedUnit.priceFor(price, selectedUnit.secondaryUnit);
    return '= Rs. ${Formatters.amount(secondaryPrice)} / ${selectedUnit.secondaryUnit}';
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: widget.product == null ? 'New Product' : 'Edit Product'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                    value: _addNewSentinel,
                    child: Text('+ Add New Category'),
                  ),
                  ...inv.categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) {
                  if (v == _addNewSentinel) {
                    _quickAddCategory();
                    return;
                  }
                  setState(() => _category = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: [
                  const DropdownMenuItem(
                    value: _addNewSentinel,
                    child: Text('+ Add New Unit'),
                  ),
                  ...inv.units.map(
                    (u) => DropdownMenuItem(value: u.id, child: Text(u.display)),
                  ),
                ],
                onChanged: (v) {
                  if (v == _addNewSentinel) {
                    _quickAddUnit();
                    return;
                  }
                  setState(() => _unit = v);
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Purchase Price',
                        helperText: _secondaryPriceHint(inv, _purchasePriceController.text),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Sale Price',
                        helperText: _secondaryPriceHint(inv, _salePriceController.text),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Opening Stock',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _thresholdController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Low Stock Threshold',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barcode (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _hsCodeController,
                      decoration: const InputDecoration(
                        labelText: 'HS Code (optional)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Save Product',
                isLoading: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitFormSheet extends StatefulWidget {
  final Unit? unit;
  const _UnitFormSheet({this.unit});

  @override
  State<_UnitFormSheet> createState() => _UnitFormSheetState();
}

class _UnitFormSheetState extends State<_UnitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.unit?.name ?? '',
  );
  late final _abbrController = TextEditingController(
    text: widget.unit?.abbreviation ?? '',
  );
  late final _secondaryController = TextEditingController(
    text: widget.unit?.secondaryUnit ?? '',
  );
  late final _secondaryAbbrController = TextEditingController(
    text: widget.unit?.secondaryAbbreviation ?? '',
  );
  late final _conversionController = TextEditingController(
    text: widget.unit?.conversionFactor?.toString() ?? '',
  );
  bool _saving = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final unit = Unit(
      id: widget.unit?.id ?? 0,
      name: _nameController.text.trim(),
      abbreviation: _abbrController.text.trim(),
      secondaryUnit: _secondaryController.text.trim(),
      secondaryAbbreviation: _secondaryAbbrController.text.trim(),
      conversionFactor: double.tryParse(_conversionController.text),
      display: '',
    );
    final ok = await context.read<InventoryProvider>().saveUnit(
      unit,
      id: widget.unit?.id,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      final err = context.read<InventoryProvider>().error;
      showAppSnackBar(context, err ?? 'Failed to save unit', isError: true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    _secondaryController.dispose();
    _secondaryAbbrController.dispose();
    _conversionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: widget.unit == null ? 'New Unit' : 'Edit Unit'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Unit Name *'),
                    validator: (v) => Validators.required(v, 'Name'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _abbrController,
                    decoration: const InputDecoration(
                      labelText: 'Abbreviation',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Secondary unit (optional, for dual-unit tracking)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _secondaryController,
                    decoration: const InputDecoration(
                      labelText: 'Secondary Unit',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _secondaryAbbrController,
                    decoration: const InputDecoration(
                      labelText: 'Abbreviation',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _conversionController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Conversion factor (e.g. 1 Box = 12 Pieces)',
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Save Unit',
              isLoading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final Category? category;
  const _CategoryFormSheet({this.category});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  bool _saving = false;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final category = Category(
      id: widget.category?.id ?? 0,
      name: _nameController.text.trim(),
      description: '',
    );
    final ok = await context.read<InventoryProvider>().saveCategory(
      category,
      id: widget.category?.id,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<InventoryProvider>().categories;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: widget.category == null ? 'New Category' : 'Edit Category'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Category Name *'),
              validator: (v) => Validators.required(v, 'Name'),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Existing categories',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: categories
                    .map((c) => Chip(label: Text(c.name)))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Save Category',
              isLoading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockAdjustDialog extends StatefulWidget {
  final Product product;
  const _StockAdjustDialog({required this.product});

  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  String _type = 'IN';
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  String get _qtyLabel => ['IN', 'OPENING', 'ADJUSTMENT'].contains(_type)
      ? 'Quantity to add'
      : 'Quantity to subtract';

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      showAppSnackBar(context, 'Enter a valid quantity', isError: true);
      return;
    }
    setState(() => _saving = true);
    final movement = StockMovement(
      id: 0,
      product: widget.product.id,
      productName: widget.product.name,
      movementType: _type,
      quantity: qty,
      note: _noteController.text.trim(),
      createdByName: '',
    );
    final ok = await context.read<InventoryProvider>().adjustStock(movement);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust Stock · ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current stock: ${Formatters.amount(widget.product.stockQuantity)} ${widget.product.unitName}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Movement Type'),
              items: AppConstants.stockMovementTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(AppConstants.stockMovementLabels[t] ?? t),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? 'IN'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: _qtyLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Save',
          expand: false,
          isLoading: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}
