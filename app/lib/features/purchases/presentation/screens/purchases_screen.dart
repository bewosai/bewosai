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
    final paymentModeLabel = p.paidAmount <= 0 && p.dueAmount > 0
        ? 'Credit'
        : (AppConstants.paymentMethodLabels[p.paymentMethod] ?? p.paymentMethod);
    showBillPrintDialog(
      context,
      documentTitle: 'Purchase Details',
      data: BillPdfData(
        businessName: business?.name ?? '',
        businessPhone: business?.phone ?? '',
        businessAddress: business?.address ?? '',
        businessPan: business?.panNumber ?? '',
        number: p.billNumber,
        partyLabel: 'Supplier',
        partyName: p.supplierName.isNotEmpty ? p.supplierName : 'Unknown',
        partyPan: p.supplierPan,
        partyAddress: p.supplierAddress,
        date: Formatters.date(p.purchaseDate),
        miti: p.purchaseDate != null ? NepaliCalendarService.fromDateTime(p.purchaseDate!) : null,
        dueDate: p.dueDate != null ? Formatters.date(p.dueDate) : null,
        paymentModeLabel: paymentModeLabel,
        items: p.items
            .map(
              (i) => BillPdfItem(
                name: i.productName,
                quantity: i.quantity,
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
  final nameController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController(text: '0');
  final discountController = TextEditingController(text: '0');

  double get qty => double.tryParse(qtyController.text) ?? 0;
  double get price => double.tryParse(priceController.text) ?? 0;
  double get discount => double.tryParse(discountController.text) ?? 0;
  double get total => (qty * price) - discount;
}

class _PurchaseFormScreenState extends State<_PurchaseFormScreen> {
  final _billNumberController = TextEditingController();
  final _taxRateController = TextEditingController(text: '13');
  final _paidController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  bool _vatEnabled = false;
  Party? _supplier;
  DateTime _purchaseDate = DateTime.now();
  DateTime? _dueDate;
  String _paymentMethod = 'CASH';
  int? _bankAccountId;
  bool _saving = false;
  bool _loaded = false;
  File? _billImageFile;
  String? _billImageUrl;
  final List<_PurchaseItemRow> _items = [_PurchaseItemRow()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<BankingProvider>().load();
      if (widget.purchase != null) {
        final p = widget.purchase!;
        _billNumberController.text = p.billNumber;
        _purchaseDate = p.purchaseDate ?? DateTime.now();
        _dueDate = p.dueDate;
        _paymentMethod = p.paymentMethod;
        _bankAccountId = p.bankAccount;
        _paidController.text = p.paidAmount.toString();
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
        for (final it in p.items) {
          final row = _PurchaseItemRow();
          row.product = it.product;
          row.nameController.text = it.productName;
          row.qtyController.text = it.quantity.toString();
          row.priceController.text = it.unitPrice.toString();
          row.discountController.text = it.discountAmount.toString();
          _items.add(row);
        }
        if (_items.isEmpty) _items.add(_PurchaseItemRow());
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
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
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
        onSelected: (p) {
          setState(() {
            item.product = p.id;
            item.nameController.text = p.name;
            item.priceController.text = p.purchasePrice.toString();
          });
        },
        onAddNew: () => _openAddProductDialog(item),
        addNewLabel: 'Add New Product',
      ),
    );
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
                  setState(() {
                    item.product = created.id;
                    item.nameController.text = created.name;
                    item.priceController.text = created.purchasePrice
                        .toString();
                  });
                  Navigator.pop(dialogContext);
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
                                  initialDate: _dueDate ?? DateTime.now(),
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
                        (e) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.navy50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _pickProduct(e.value),
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Product',
                                          isDense: true,
                                        ),
                                        child: Text(
                                          e.value.nameController.text.isEmpty
                                              ? 'Select product'
                                              : e.value.nameController.text,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_items.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () => setState(
                                        () => _items.removeAt(e.key),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: e.value.qtyController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: const InputDecoration(
                                        labelText: 'Qty',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 4,
                                    child: TextField(
                                      controller: e.value.priceController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: const InputDecoration(
                                        labelText: 'Cost',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 4,
                                    child: TextField(
                                      controller: e.value.discountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: const TextStyle(fontSize: 13),
                                      decoration: const InputDecoration(
                                        labelText: 'Disc.',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '= ${Formatters.currency(e.value.total)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _items.add(_PurchaseItemRow())),
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
                              items: AppConstants.paymentMethods
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
