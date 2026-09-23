import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/calendar/nepali_calendar_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/payment_status.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/pdf/bill_pdf.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../banking/presentation/providers/banking_provider.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../inventory/data/models/inventory_model.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../parties/data/models/party_model.dart';
import '../../../parties/presentation/providers/party_provider.dart';
import '../../data/models/purchase_model.dart';
import '../providers/purchase_provider.dart';
import '../../../../core/calendar/nepal_time.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String _filter = 'ALL';
  String _paymentFilter = 'ALL';
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().load();
      context.read<PartyProvider>().load();
      context.read<InventoryProvider>().load();
    });
  }

  void _print(Purchase p) {
    final business = context.read<AuthProvider>().currentBusiness;
    // Mode of Payment (channel) and Bill Type (paid now vs owed) are
    // separate facts — see the Cash/Credit toggle on the form itself.
    final paymentModeLabel = AppConstants.paymentMethodLabels[p.paymentMethod] ?? p.paymentMethod;
    final billType = p.paidAmount <= 0 && p.dueAmount > 0 ? 'Credit' : 'Cash';
    showBillPrintDialog(
      context,
      documentTitle: 'Proforma Invoice',
      data: BillPdfData(
        businessName: business?.name ?? '',
        businessPhone: business?.phone ?? '',
        businessAddress: business?.address ?? '',
        businessPan: business?.panNumber ?? '',
        businessVat: business?.vatNumber ?? '',
        number: p.billNumber,
        partyLabel: 'Supplier',
        partyName: p.supplierName.isNotEmpty ? p.supplierName : 'Unknown',
        partyPan: p.supplierPan,
        partyAddress: p.supplierAddress,
        partyPhone: p.supplierPhone,
        date: Formatters.date(p.purchaseDate),
        miti: p.purchaseDate != null ? NepaliCalendarService.fromDateTime(p.purchaseDate!) : null,
        dueDate: p.dueDate != null ? Formatters.date(p.dueDate) : null,
        paymentModeLabel: paymentModeLabel,
        billType: billType,
        items: p.items
            .map(
              (i) => BillPdfItem(
                name: i.productName,
                hsCode: i.hsCode,
                quantity: i.quantity,
                unitLabel: i.unitLabel.isNotEmpty ? i.unitLabel : i.productUnitName,
                unitPrice: i.unitPrice,
                discountAmount: i.discountAmount,
                total: i.total,
              ),
            )
            .toList(),
        subtotal: p.subtotal,
        discount: p.discount,
        taxRate: p.taxRate,
        taxAmount: p.taxAmount,
        total: p.total,
        paidAmount: p.paidAmount,
        dueAmount: p.dueAmount,
        notes: p.notes,
      ),
    );
  }

  List<Purchase> _filtered(List<Purchase> purchases) {
    var list = purchases;
    if (_filter != 'ALL') {
      list = list.where((p) => p.status == _filter).toList();
    }
    if (_paymentFilter != 'ALL') {
      list = list
          .where((p) => paymentStatus(total: p.total, paid: p.paidAmount) == _paymentFilter)
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (p) =>
                p.billNumber.toLowerCase().contains(q) ||
                p.supplierName.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PurchaseProvider>();
    final filtered = _filtered(pp.purchases);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'purchases_fab',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const _PurchaseFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: () => context.read<PurchaseProvider>().load(),
          child: pp.isLoading && pp.purchases.isEmpty
              ? const LoadingView()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ResponsiveGrid(
                      columns: 2,
                      spacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        KpiCard.currency(
                          label: 'This Month',
                          value: pp.thisMonthTotal,
                          icon: Icons.calendar_month_outlined,
                          color: AppColors.orange,
                        ),
                        KpiCard.currency(
                          label: 'Payable',
                          value: pp.totalPayable,
                          icon: Icons.call_made,
                          color: AppColors.warning,
                        ),
                        KpiCard(
                          label: 'Total Bills',
                          value: '${pp.purchases.length}',
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SearchField(
                      hint: 'Search bill # or supplier',
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['ALL', 'DRAFT', 'CONFIRMED', 'CANCELLED']
                            .map((f) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: AppFilterChip(
                                  label: f,
                                  selected: _filter == f,
                                  onTap: () => setState(() => _filter = f),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['ALL', 'PAID', 'PARTIAL', 'UNPAID'].map((
                          f,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppFilterChip(
                              label: f == 'ALL' ? 'All Payments' : f[0] + f.substring(1).toLowerCase(),
                              selected: _paymentFilter == f,
                              onTap: () => setState(() => _paymentFilter = f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.shopping_bag_outlined,
                        title: 'No purchases found',
                        message: 'Record your first purchase bill.',
                      )
                    else
                      ...filtered.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    _PurchaseFormScreen(purchase: p),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.billNumber,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${p.supplierName.isNotEmpty ? p.supplierName : 'Unknown'} · ${Formatters.dateShort(p.purchaseDate)}',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (p.createdAt != null)
                                        Text(
                                          'Added ${Formatters.dateShort(p.createdAt)}',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatters.currency(p.total),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    // Due (or an overpaid advance) shown right
                                    // under the total — previously only
                                    // inferable from the badge below.
                                    if (p.dueAmount > 0)
                                      Text(
                                        'Due ${Formatters.currency(p.dueAmount)}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                                      )
                                    else if (p.dueAmount < 0)
                                      Text(
                                        'Advance ${Formatters.currency(p.dueAmount.abs())}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                                      ),
                                    const SizedBox(height: 4),
                                    StatusBadge(label: p.status),
                                    const SizedBox(height: 4),
                                    StatusBadge(
                                      label: paymentStatus(total: p.total, paid: p.paidAmount),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.print_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => _print(p),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final provider = context
                                        .read<PurchaseProvider>();
                                    final confirmed = await showDeleteConfirmDialog(
                                      context,
                                      message:
                                          'This purchase will be moved to Recycle Bin.',
                                    );
                                    if (confirmed) provider.delete(p.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PurchaseFormScreen extends StatefulWidget {
  final Purchase? purchase;
  const _PurchaseFormScreen({this.purchase});

  @override
  State<_PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseItemRow {
  int? product;
  // Which of the product's units this line is billed in (e.g. "Piece" vs
  // the product's primary "Box") — see Unit.priceFor/base_quantity_for.
  String unitLabel = '';
  Unit? unitDetail;
  // The product's purchase price in its *primary* unit — see
  // quick_pos_screen.dart's _LineItem.basePrice for why this is kept
  // separate from priceController.text.
  double basePrice = 0;
  final nameController = TextEditingController();
  final qtyController = TextEditingController(text: '0');
  final priceController = TextEditingController(text: '0');
  final discountController = TextEditingController(text: '0');

  double get qty => double.tryParse(qtyController.text) ?? 0;
  double get price => double.tryParse(priceController.text) ?? 0;
  double get discount => Validators.cappedDiscount(discountController.text, qty * price);
  double get total => (qty * price) - discount;
}

class _PurchaseFormScreenState extends State<_PurchaseFormScreen> {
  final _billNumberController = TextEditingController();
  final _taxRateController = TextEditingController(text: '13');
  final _paidController = TextEditingController(text: '0');
  final _cashAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  bool _vatEnabled = false;
  Party? _supplier;
  DateTime _purchaseDate = NepalTime.now();
  DateTime? _dueDate;
  String _paymentMethod = 'CASH';
  int? _bankAccountId;
  // Separate from _paymentMethod — see quick_pos_screen.dart's identical
  // field for the reasoning. Only snaps Amount Paid when tapped, not kept
  // continuously in sync afterward.
  bool _creditSale = false;
  bool _saving = false;
  bool _loaded = false;
  File? _billImageFile;
  String? _billImageUrl;
  // Starts empty: an item only lands here once picked and confirmed in the
  // item-detail sheet (see _pickProduct / _showItemDetailSheet).
  final List<_PurchaseItemRow> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<BankingProvider>().load();
      if (widget.purchase != null) {
        final p = widget.purchase!;
        _billNumberController.text = p.billNumber;
        _purchaseDate = p.purchaseDate ?? NepalTime.now();
        _dueDate = p.dueDate;
        _paymentMethod = p.paymentMethod;
        _bankAccountId = p.bankAccount;
        _paidController.text = p.paidAmount.toString();
        _cashAmountController.text = p.cashAmount.toString();
        _creditSale = p.dueAmount > 0;
        _notesController.text = p.notes;
        _billImageUrl = p.billImageUrl;
        _vatEnabled = p.taxRate > 0;
        if (p.taxRate > 0) {
          _taxRateController.text = p.taxRate == p.taxRate.roundToDouble()
              ? p.taxRate.toStringAsFixed(0)
              : p.taxRate.toString();
        }
        final parties = context.read<PartyProvider>().parties;
        if (p.supplier != null) {
          final match = parties.where((s) => s.id == p.supplier);
          if (match.isNotEmpty) _supplier = match.first;
        }
        _items.clear();
        final invProducts = context.read<InventoryProvider>().products;
        for (final it in p.items) {
          final row = _PurchaseItemRow();
          row.product = it.product;
          row.nameController.text = it.productName;
          row.unitLabel = it.unitLabel;
          final match = invProducts.where((prod) => prod.id == it.product);
          if (match.isNotEmpty) {
            row.unitDetail = match.first.unitDetail;
            row.basePrice = match.first.purchasePrice;
          }
          row.qtyController.text = it.quantity.toString();
          row.priceController.text = it.unitPrice.toString();
          row.discountController.text = it.discountAmount.toString();
          _items.add(row);
        }
      } else {
        final businessTaxRate = context.read<AuthProvider>().currentBusiness?.defaultTaxRate;
        if (businessTaxRate != null) {
          _taxRateController.text = businessTaxRate == businessTaxRate.roundToDouble()
              ? businessTaxRate.toStringAsFixed(0)
              : businessTaxRate.toString();
        }
        final next = await context.read<PurchaseProvider>().nextNumber();
        _billNumberController.text = next;
      }
      if (mounted) setState(() => _loaded = true);
    });
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.total);
  double get _taxRate => double.tryParse(_taxRateController.text) ?? 0;
  double get _taxAmount => _vatEnabled ? _subtotal * _taxRate / 100 : 0;
  double get _total => _subtotal + _taxAmount;
  double get _paid => double.tryParse(_paidController.text) ?? 0;
  double get _cashAmount =>
      (double.tryParse(_cashAmountController.text) ?? 0).clamp(0, _paid);
  // Not clamped — matches the backend's due_amount exactly (total - paid),
  // which goes negative on overpayment rather than hiding it as zero.
  double get _balanceDue => _total - _paid;
  bool get _isAdvance => _balanceDue < 0;

  void _pickSupplier() {
    final suppliers = context.read<PartyProvider>().suppliers;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SearchSheet<Party>(
        title: 'Select Supplier',
        items: suppliers,
        labelBuilder: (p) => p.name,
        subtitleBuilder: (p) => p.phone,
        onSelected: (p) => setState(() => _supplier = p),
        onAddNew: _openAddSupplierDialog,
        addNewLabel: 'Add New Supplier',
      ),
    );
  }

  Future<void> _openAddSupplierDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add New Supplier'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Supplier Name *',
                    ),
                    validator: (v) => Validators.required(v, 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
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
                final partyProvider = context.read<PartyProvider>();
                final created = await partyProvider.quickCreate(
                  Party(
                    id: 0,
                    name: nameController.text.trim(),
                    partyType: 'SUPPLIER',
                    customerType: '',
                    phone: phoneController.text.trim(),
                    email: '',
                    address: '',
                    panNumber: '',
                    vatNumber: '',
                    openingBalance: 0,
                    balance: 0,
                    notes: '',
                    isActive: true,
                  ),
                );
                if (!dialogContext.mounted) return;
                if (created != null) {
                  setState(() => _supplier = created);
                  Navigator.pop(dialogContext);
                } else {
                  setDialogState(() => saving = false);
                  showAppSnackBar(
                    dialogContext,
                    partyProvider.error ?? 'Failed to add supplier',
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

  Future<void> _pickBillImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600, maxHeight: 1600);
    if (picked == null || !mounted) return;
    setState(() {
      _billImageFile = File(picked.path);
      _billImageUrl = null;
    });
  }

  void _removeBillImage() {
    setState(() {
      _billImageFile = null;
      _billImageUrl = null;
    });
  }

  void _pickProduct(_PurchaseItemRow item) {
    final products = context.read<InventoryProvider>().products;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SearchSheet<Product>(
        title: 'Select Product',
        items: products,
        labelBuilder: (p) => p.name,
        subtitleBuilder: (p) => Formatters.currency(p.purchasePrice),
        // Same category/stock/price layout as the invoice screen's picker.
        detailBuilder: (ctx, p) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    p.categoryName.isEmpty ? 'Uncategorized' : p.categoryName,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                        child: StatusBadge(label: 'LOW', color: AppColors.error),
                      ),
                    Text(
                      '${Formatters.amount(p.stockQuantity)} ${p.unitName}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  Formatters.currency(p.purchasePrice),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        onSelected: (p) => _showItemDetailSheet(item, p),
        onAddNew: () => _openAddProductDialog(item),
        addNewLabel: 'Add New Product',
      ),
    );
  }

  /// Shown right after a product is picked (or newly created) — its own
  /// detail (category, stock, cost) plus editable Quantity/Cost/Discount and
  /// a live total, so the item only lands on the bill once reviewed.
  void _showItemDetailSheet(_PurchaseItemRow item, Product p, {bool showStock = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PurchaseItemDetailSheet(
        product: p,
        initialQty: item.product == p.id && item.qty > 0 ? item.qty : 1,
        initialCost: item.product == p.id && item.price > 0 ? item.price : p.purchasePrice,
        initialDiscount: item.product == p.id ? item.discount : 0,
        initialUnitLabel: item.product == p.id ? item.unitLabel : '',
        showStock: showStock,
        onAdd: (qty, cost, discount, unitLabel) {
          setState(() {
            if (p.id != 0) item.product = p.id;
            item.nameController.text = p.name;
            item.unitDetail = p.unitDetail;
            item.unitLabel = unitLabel;
            item.basePrice = p.purchasePrice;
            item.qtyController.text = qty.toString();
            item.priceController.text = cost.toString();
            item.discountController.text = discount.toString();
            if (!_items.contains(item)) _items.add(item);
          });
        },
      ),
    );
  }

  /// Re-opens the detail sheet pre-filled from the line, so editing and
  /// adding look and behave identically.
  void _editItem(_PurchaseItemRow item) {
    final match = context.read<InventoryProvider>().products.where((p) => p.id == item.product);
    if (match.isNotEmpty) {
      _showItemDetailSheet(item, match.first);
      return;
    }
    _showItemDetailSheet(
      item,
      Product(
        id: item.product ?? 0,
        name: item.nameController.text,
        categoryName: '',
        unitName: item.unitLabel,
        unitDetail: item.unitDetail,
        description: '',
        purchasePrice: item.basePrice > 0 ? item.basePrice : item.price,
        salePrice: 0,
        stockQuantity: 0,
        lowStockThreshold: 0,
        isLowStock: false,
        barcode: '',
        isActive: true,
      ),
      showStock: false,
    );
  }

  /// Removes a line, with a one-tap Undo.
  void _removeItem(int index) {
    final removed = _items[index];
    setState(() => _items.removeAt(index));
    final name = removed.nameController.text.trim().isEmpty ? 'Item' : removed.nameController.text.trim();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('$name removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            setState(() => _items.insert(index.clamp(0, _items.length), removed));
          },
        ),
      ));
  }

  Future<void> _openAddProductDialog(_PurchaseItemRow item) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                    ),
                    validator: (v) => Validators.required(v, 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price *',
                    ),
                    validator: (v) =>
                        Validators.positiveNumber(v, 'Price') ??
                        (v == null || v.isEmpty ? 'Price is required' : null),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Opening Stock (optional)',
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
                final created = await invProvider.quickCreate(
                  Product(
                    id: 0,
                    name: nameController.text.trim(),
                    categoryName: '',
                    unitName: '',
                    description: '',
                    purchasePrice: double.tryParse(priceController.text) ?? 0,
                    salePrice: 0,
                    stockQuantity: double.tryParse(stockController.text) ?? 0,
                    lowStockThreshold: 5,
                    isLowStock: false,
                    barcode: '',
                    isActive: true,
                  ),
                );
                if (!dialogContext.mounted) return;
                if (created != null) {
                  Navigator.pop(dialogContext);
                  if (mounted) _showItemDetailSheet(item, created);
                } else {
                  setDialogState(() => saving = false);
                  showAppSnackBar(
                    dialogContext,
                    invProvider.error ?? 'Failed to add product',
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

  Future<void> _save(String status) async {
    if (_items.every((i) => i.qty <= 0)) {
      showAppSnackBar(
        context,
        'Add at least one item with quantity',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    final purchase = Purchase(
      id: widget.purchase?.id ?? 0,
      billNumber: _billNumberController.text.trim(),
      supplier: _supplier?.id,
      supplierName: _supplier?.name ?? '',
      purchaseDate: _purchaseDate,
      dueDate: _dueDate,
      subtotal: _subtotal,
      discount: 0,
      taxRate: _vatEnabled ? _taxRate : 0,
      taxAmount: _taxAmount,
      total: _total,
      paidAmount: _paid,
      dueAmount: _balanceDue,
      paymentMethod: _paymentMethod,
      bankAccount: _paymentMethod != 'CASH' ? _bankAccountId : null,
      cashAmount: _paymentMethod == 'SPLIT' ? _cashAmount : 0,
      status: status,
      notes: _notesController.text.trim(),
      items: _items
          .where((i) => i.qty > 0)
          .map(
            (i) => PurchaseItem(
              product: i.product,
              productName: i.nameController.text.trim().isEmpty
                  ? 'Item'
                  : i.nameController.text.trim(),
              unitLabel: i.unitLabel,
              quantity: i.qty,
              unitPrice: i.price,
              discountAmount: i.discount,
            ),
          )
          .toList(),
    );
    final result = await context.read<PurchaseProvider>().save(
      purchase,
      id: widget.purchase?.id,
      billImage: _billImageFile,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) {
      Navigator.pop(context);
    } else {
      final err = context.read<PurchaseProvider>().error;
      showAppSnackBar(context, err ?? 'Failed to save purchase', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.purchase != null ? 'Edit Purchase' : 'New Purchase'),
        actions: const [HomeLogoButton()],
      ),
      body: ResponsiveBody(
        child: !_loaded
            ? const LoadingView()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  AppSectionCard(
                    children: [
                      InkWell(
                        onTap: _pickSupplier,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Supplier',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                          child: Text(_supplier?.name ?? 'Select supplier'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _billNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Bill Number',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await AppDatePicker.pick(
                                  context,
                                  initialDate: _purchaseDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _purchaseDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Purchase Date',
                                  isDense: true,
                                ),
                                child: Text(Formatters.date(_purchaseDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await AppDatePicker.pick(
                                  context,
                                  initialDate: _dueDate ?? NepalTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _dueDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Due Date',
                                  isDense: true,
                                ),
                                child: Text(
                                  _dueDate != null
                                      ? Formatters.date(_dueDate)
                                      : 'Not set',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    title: 'Items',
                    children: [
                      ..._items.asMap().entries.map(
                        (e) => _PurchaseLineItemRow(
                          index: e.key + 1,
                          item: e.value,
                          onEdit: () => _editItem(e.value),
                          onRemove: () => _removeItem(e.key),
                        ),
                      ),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'No items yet — tap "Add Item" to choose a product.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _pickProduct(_PurchaseItemRow()),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    title: 'Payment',
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text(Formatters.currency(_subtotal)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('VAT / Tax'),
                              Switch(
                                value: _vatEnabled,
                                onChanged: (v) => setState(() => _vatEnabled = v),
                              ),
                              if (_vatEnabled)
                                SizedBox(
                                  width: 64,
                                  child: TextField(
                                    controller: _taxRateController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: '%'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                            ],
                          ),
                          if (_vatEnabled) Text(Formatters.currency(_taxAmount)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            Formatters.currency(_total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bill Image (optional)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _BillImagePicker(
                        imageFile: _billImageFile,
                        imageUrl: _billImageUrl,
                        onTap: _pickBillImage,
                        onRemove: _removeBillImage,
                      ),
                      const SizedBox(height: 12),
                      Text('Cash or Credit?', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() {
                                _creditSale = false;
                                _paidController.text = _total.toStringAsFixed(2);
                              }),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !_creditSale ? AppColors.orange : null,
                                foregroundColor: !_creditSale ? Colors.white : AppColors.textSecondary,
                                side: BorderSide(color: !_creditSale ? AppColors.orange : AppColors.divider),
                              ),
                              child: const Text('Cash'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() {
                                _creditSale = true;
                                _paidController.text = '0';
                              }),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _creditSale ? AppColors.orange : null,
                                foregroundColor: _creditSale ? Colors.white : AppColors.textSecondary,
                                side: BorderSide(color: _creditSale ? AppColors.orange : AppColors.divider),
                              ),
                              child: const Text('Credit'),
                            ),
                          ),
                        ],
                      ),
                      if (_creditSale)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Nothing paid yet — set a Due Date above so this shows up as overdue if unpaid.',
                            style: TextStyle(fontSize: 11, color: AppColors.warning),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _paidController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Amount Paid',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _paymentMethod,
                              decoration: const InputDecoration(
                                labelText: 'Method',
                              ),
                              items: AppConstants.paymentMethodsWithSplit
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        AppConstants.paymentMethodLabels[m] ??
                                            m,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _paymentMethod = v ?? 'CASH';
                                if (_paymentMethod == 'CASH') _bankAccountId = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                      if (_paymentMethod != 'CASH') ...[
                        const SizedBox(height: 12),
                        Consumer<BankingProvider>(
                          builder: (context, bp, _) {
                            final accounts = bp.accounts;
                            if (accounts.isEmpty) {
                              return Text(
                                'No bank accounts set up yet — add one from Banking to track this payment on a statement.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            }
                            return DropdownButtonFormField<int>(
                              initialValue: accounts.any((a) => a.id == _bankAccountId)
                                  ? _bankAccountId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Paid From Account',
                              ),
                              items: accounts
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.accountName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _bankAccountId = v),
                            );
                          },
                        ),
                      ],
                      if (_paymentMethod == 'SPLIT') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _cashAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cash Amount',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rest paid from the account above — ${Formatters.currency((_paid - _cashAmount).clamp(0, _paid))}',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isAdvance ? 'Advance (Overpaid)' : 'Balance Due',
                          ),
                          Text(
                            Formatters.currency(
                              _isAdvance ? -_balanceDue : _balanceDue,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _balanceDue > 0
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _save('DRAFT'),
                  child: const Text('Save as Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Confirm Purchase',
                  isLoading: _saving,
                  onPressed: () => _save('CONFIRMED'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillImagePicker extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BillImagePicker({
    required this.imageFile,
    required this.imageUrl,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || imageUrl != null;
    if (!hasImage) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 90,
          width: 90,
          decoration: BoxDecoration(
            color: AppColors.navy50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.navy300),
          ),
          child: Icon(
            Icons.add_a_photo_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageFile != null
                ? Image.file(imageFile!, height: 90, width: 90, fit: BoxFit.cover)
                : Image.network(imageUrl!, height: 90, width: 90, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dropdown picking which of the product's units a purchase line is billed
/// in — see quick_pos_screen.dart's `_UnitToggle` for the full rationale
/// (identical mechanism, purchase side).
/// One purchase line as a compact box — name, quantity x cost, any discount
/// and the line total — with edit and delete side by side. Editing opens the
/// same detail sheet used to add the item.
class _PurchaseLineItemRow extends StatelessWidget {
  final int index;
  final _PurchaseItemRow item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _PurchaseLineItemRow({
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = item.nameController.text.trim().isEmpty ? 'Item' : item.nameController.text.trim();
    final unit = item.unitLabel.isEmpty ? '' : ' ${item.unitLabel}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.navy50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orangeDark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.amount(item.qty)}$unit × ${Formatters.currency(item.price)}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                    if (item.discount > 0)
                      Text(
                        'Discount − ${Formatters.currency(item.discount)}',
                        style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 2),
                    child: Text(
                      Formatters.currency(item.total),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: Icon(Icons.edit_outlined, size: 19, color: AppColors.textSecondary),
                        onPressed: onEdit,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.error),
                        onPressed: onRemove,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reviews/edits Quantity, Cost and Discount against the product's own detail
/// before it's added to the bill, with a live running total — mirrors the
/// invoice screen's _ItemDetailSheet, with "Cost" in place of "Price".
class _PurchaseItemDetailSheet extends StatefulWidget {
  final Product product;
  final double initialQty;
  final double initialCost;
  final double initialDiscount;
  final String initialUnitLabel;
  final bool showStock;
  final void Function(double qty, double cost, double discount, String unitLabel) onAdd;

  const _PurchaseItemDetailSheet({
    required this.product,
    required this.initialQty,
    required this.initialCost,
    required this.initialDiscount,
    required this.onAdd,
    this.initialUnitLabel = '',
    this.showStock = true,
  });

  @override
  State<_PurchaseItemDetailSheet> createState() => _PurchaseItemDetailSheetState();
}

class _PurchaseItemDetailSheetState extends State<_PurchaseItemDetailSheet> {
  static String _clean(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  final _formKey = GlobalKey<FormState>();
  late final _qtyController = TextEditingController(text: _clean(widget.initialQty));
  late final _costController = TextEditingController(text: _clean(widget.initialCost));
  late final _discountController = TextEditingController(
    text: widget.initialDiscount == 0 ? '' : _clean(widget.initialDiscount),
  );
  late String _unitLabel = _resolveUnit();

  // The dropdown asserts its value is exactly one of its items, and a saved
  // line's unit label can differ in case/spacing — snap to the real unit name.
  String _resolveUnit() {
    final unit = widget.product.unitDetail;
    final wanted = widget.initialUnitLabel.trim().toLowerCase();
    if (unit != null && unit.hasSecondary) {
      return wanted == unit.secondaryUnit.trim().toLowerCase() ? unit.secondaryUnit : unit.name;
    }
    return widget.initialUnitLabel.isNotEmpty
        ? widget.initialUnitLabel
        : (unit?.name ?? widget.product.unitName);
  }

  double get _qty => double.tryParse(_qtyController.text) ?? 0;
  double get _cost => double.tryParse(_costController.text) ?? 0;
  double get _discount => Validators.cappedDiscount(_discountController.text, _qty * _cost);
  double get _total => (_qty * _cost) - _discount;

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(title: p.name),
                const SizedBox(height: 8),
                Text(
                  p.categoryName.isEmpty ? 'Uncategorized' : p.categoryName,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.showStock && p.isLowStock) ...[
                            const StatusBadge(label: 'LOW', color: AppColors.error),
                            const SizedBox(width: 6),
                          ],
                          if (widget.showStock)
                            Flexible(
                              child: Text(
                                '${Formatters.amount(p.stockQuantity)} ${p.unitName} in stock',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      Formatters.currency(p.purchasePrice),
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (p.unitDetail?.hasSecondary == true) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _unitLabel,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [p.unitDetail!.name, p.unitDetail!.secondaryUnit]
                        .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                        .toList(),
                    onChanged: (label) {
                      if (label == null || label == _unitLabel) return;
                      setState(() {
                        _unitLabel = label;
                        _costController.text = _clean(p.unitDetail!.priceFor(p.purchasePrice, label));
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Quantity *'),
                        validator: (v) =>
                            Validators.required(v, 'Quantity') ?? Validators.positiveNumber(v, 'Quantity'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Cost *'),
                        validator: (v) =>
                            Validators.required(v, 'Cost') ?? Validators.positiveNumber(v, 'Cost'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Discount'),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) => Validators.discount(v, _qty * _cost),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    Text(
                      Formatters.currency(_total),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: 'Add to Bill',
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) return;
                          widget.onAdd(_qty, _cost, _discount, _unitLabel);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
