import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/notifications/notification_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../shared/widgets/app_widgets.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../banking/presentation/providers/banking_provider.dart';
import '../../../../inventory/data/models/inventory_model.dart';
import '../../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../../parties/data/models/party_model.dart';
import '../../../../parties/presentation/providers/party_provider.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/services/sale_service.dart';
import '../../providers/sale_provider.dart';

class QuickPosScreen extends StatefulWidget {
  final int? saleId;
  /// A still-queued offline sale (see [Sale.syncError]) to edit and resend,
  /// passed directly instead of by ID since it has no server record yet to
  /// fetch it from.
  final Sale? pendingEdit;
  const QuickPosScreen({super.key, this.saleId, this.pendingEdit});

  @override
  State<QuickPosScreen> createState() => _QuickPosScreenState();
}

class _LineItem {
  int? product;
  // Which of the product's units this line is billed in (e.g. "Piece" vs
  // the product's primary "Box") — see Unit.priceFor/base_quantity_for.
  // Blank means the primary unit.
  String unitLabel = '';
  Unit? unitDetail;
  // The product's sale price in its *primary* unit — kept separately from
  // priceController.text (which may already hold a secondary-unit-adjusted
  // price) so toggling the unit back and forth always recomputes from the
  // true base price instead of compounding conversions on itself.
  double basePrice = 0;
  final nameController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController(text: '0');
  final discountController = TextEditingController(text: '0');

  double get qty => double.tryParse(qtyController.text) ?? 0;
  double get price => double.tryParse(priceController.text) ?? 0;
  double get discount => double.tryParse(discountController.text) ?? 0;
  double get total => (qty * price) - discount;

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
  }
}

class _QuickPosScreenState extends State<QuickPosScreen> {
  final _invoiceController = TextEditingController();
  final _discountPctController = TextEditingController(text: '0');
  final _taxRateController = TextEditingController(text: '13');
  final _paidController = TextEditingController(text: '0');
  final _cashAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  Party? _customer;
  DateTime _saleDate = DateTime.now();
  DateTime? _dueDate;
  String _paymentMethod = 'CASH';
  int? _bankAccountId;
  bool _vatEnabled = false;
  // Separate from _paymentMethod (which channel it'll settle through) —
  // Credit means nothing is collected today regardless of method. Only
  // snaps Amount Paid to the current total/zero the moment it's tapped,
  // not continuously kept in sync as items change afterward.
  bool _creditSale = false;
  bool _saving = false;
  bool _loaded = false;
  int? _editId;
  bool _isPendingEdit = false;
  bool _reminderEnabled = false;
  DateTime? _reminderAt;

  final List<_LineItem> _items = [_LineItem()];

  @override
  void initState() {
    super.initState();
    _editId = widget.saleId ?? widget.pendingEdit?.id;
    _isPendingEdit = widget.pendingEdit != null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final partyProvider = context.read<PartyProvider>();
      final invProvider = context.read<InventoryProvider>();
      final saleProvider = context.read<SaleProvider>();
      context.read<BankingProvider>().load();
      final businessTaxRate = context.read<AuthProvider>().currentBusiness?.defaultTaxRate;
      if (businessTaxRate != null && _editId == null) {
        _taxRateController.text = businessTaxRate == businessTaxRate.roundToDouble()
            ? businessTaxRate.toStringAsFixed(0)
            : businessTaxRate.toString();
      }
      if (partyProvider.parties.isEmpty) await partyProvider.load();
      if (invProvider.products.isEmpty) await invProvider.load();

      if (_isPendingEdit) {
        _prefill(widget.pendingEdit!, partyProvider);
      } else if (_editId != null) {
        Sale? sale;
        try {
          sale = await SaleService().get(_editId!);
        } catch (_) {}
        if (sale != null) _prefill(sale, partyProvider);
      } else {
        final next = await saleProvider.nextNumber();
        if (mounted) setState(() => _invoiceController.text = next);
      }
      if (mounted) setState(() => _loaded = true);
    });
  }

  void _prefill(Sale sale, PartyProvider partyProvider) {
    _invoiceController.text = sale.invoiceNumber;
    _saleDate = sale.saleDate ?? DateTime.now();
    _dueDate = sale.dueDate;
    _paymentMethod = sale.paymentMethod;
    _bankAccountId = sale.bankAccount;
    _vatEnabled = sale.taxRate > 0;
    _reminderEnabled = sale.reminderEnabled;
    _reminderAt = sale.reminderAt;
    if (sale.taxRate > 0) {
      _taxRateController.text = sale.taxRate == sale.taxRate.roundToDouble()
          ? sale.taxRate.toStringAsFixed(0)
          : sale.taxRate.toString();
    }
    _paidController.text = sale.paidAmount.toString();
    _cashAmountController.text = sale.cashAmount.toString();
    _creditSale = sale.dueAmount > 0;
    _notesController.text = sale.notes;
    _discountPctController.text = sale.subtotal > 0
        ? ((sale.discount / sale.subtotal) * 100).toStringAsFixed(2)
        : '0';
    if (sale.customer != null) {
      final match = partyProvider.parties.where((p) => p.id == sale.customer);
      if (match.isNotEmpty) _customer = match.first;
    }
    _items.clear();
    final invProducts = context.read<InventoryProvider>().products;
    for (final it in sale.items) {
      final li = _LineItem();
      li.product = it.product;
      li.nameController.text = it.productName;
      li.unitLabel = it.unitLabel;
      final match = invProducts.where((p) => p.id == it.product);
      if (match.isNotEmpty) {
        li.unitDetail = match.first.unitDetail;
        li.basePrice = match.first.salePrice;
      }
      li.qtyController.text = it.quantity.toString();
      li.priceController.text = it.unitPrice.toString();
      li.discountController.text = it.discountAmount.toString();
      _items.add(li);
    }
    if (_items.isEmpty) _items.add(_LineItem());
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    _invoiceController.dispose();
    _discountPctController.dispose();
    _taxRateController.dispose();
    _paidController.dispose();
    _cashAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.total);
  double get _discountPct => double.tryParse(_discountPctController.text) ?? 0;
  double get _discountAmount => _subtotal * _discountPct / 100;
  double get _taxable => _subtotal - _discountAmount;
  double get _taxRate => double.tryParse(_taxRateController.text) ?? 0;
  double get _taxAmount => _vatEnabled ? _taxable * _taxRate / 100 : 0;
  double get _total => _taxable + _taxAmount;
  double get _paid => double.tryParse(_paidController.text) ?? 0;
  double get _cashAmount =>
      (double.tryParse(_cashAmountController.text) ?? 0).clamp(0, _paid);
  // Not clamped to 0 — matches the backend's due_amount exactly (total - paid),
  // which goes negative on overpayment. Clamping here would hide a genuine
  // advance/credit balance from the user while they're filling out the form.
  double get _balanceDue => _total - _paid;
  bool get _isAdvance => _balanceDue < 0;

  void _pickProduct(_LineItem item) {
    final products = context.read<InventoryProvider>().products;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SearchSheet<Product>(
        title: 'Select Product',
        items: products,
        labelBuilder: (p) => p.name,
        subtitleBuilder: (p) =>
            '${Formatters.currency(p.salePrice)} · Stock: ${Formatters.amount(p.stockQuantity)}',
        onSelected: (p) {
          setState(() {
            item.product = p.id;
            item.nameController.text = p.name;
            item.unitDetail = p.unitDetail;
            item.unitLabel = p.unitDetail?.name ?? '';
            item.basePrice = p.salePrice;
            item.priceController.text = p.salePrice.toString();
          });
        },
        onAddNew: () => _openAddProductDialog(item),
        addNewLabel: 'Add New Product',
      ),
    );
  }

  Future<void> _openAddProductDialog(_LineItem item) async {
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
                      labelText: 'Sale Price *',
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
                    purchasePrice: 0,
                    salePrice: double.tryParse(priceController.text) ?? 0,
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
                    item.unitDetail = created.unitDetail;
                    item.unitLabel = created.unitDetail?.name ?? '';
                    item.basePrice = created.salePrice;
                    item.priceController.text = created.salePrice.toString();
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

  void _pickCustomer() {
    final customers = context.read<PartyProvider>().customers;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SearchSheet<Party>(
        title: 'Select Customer',
        items: customers,
        labelBuilder: (p) => p.name,
        subtitleBuilder: (p) => p.phone,
        onSelected: (p) => setState(() => _customer = p),
        allowClear: true,
        onClear: () => setState(() => _customer = null),
        onAddNew: _openAddCustomerDialog,
        addNewLabel: 'Add New Customer',
      ),
    );
  }

  Future<void> _openAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add New Customer'),
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
                      labelText: 'Customer Name *',
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
                    partyType: 'CUSTOMER',
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
                  setState(() => _customer = created);
                  Navigator.pop(dialogContext);
                } else {
                  setDialogState(() => saving = false);
                  showAppSnackBar(
                    dialogContext,
                    partyProvider.error ?? 'Failed to add customer',
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
    if (_paymentMethod != 'CASH' && _bankAccountId == null) {
      showAppSnackBar(
        context,
        'Select which account this payment should hit',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    final sale = Sale(
      id: _editId ?? 0,
      invoiceNumber: _invoiceController.text.trim(),
      customer: _customer?.id,
      customerName: _customer?.name ?? '',
      partyPhone: _customer?.phone ?? '',
      saleDate: _saleDate,
      dueDate: _dueDate,
      subtotal: _subtotal,
      discount: _discountAmount,
      taxRate: _vatEnabled ? _taxRate : 0,
      taxAmount: _taxAmount,
      total: _total,
      paidAmount: _paid,
      dueAmount: _balanceDue,
      paymentMethod: _paymentMethod,
      bankAccount: _paymentMethod != 'CASH' ? _bankAccountId : null,
      cashAmount: _paymentMethod == 'SPLIT' ? _cashAmount : 0,
      status: status,
      saleType: 'SALE',
      notes: _notesController.text.trim(),
      reminderEnabled: _reminderEnabled,
      reminderAt: _reminderEnabled ? _reminderAt : null,
      items: _items
          .where((i) => i.qty > 0)
          .map(
            (i) => SaleItem(
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

    final result = _isPendingEdit
        ? await context.read<SaleProvider>().updatePendingSale(_editId!, sale)
        : await context.read<SaleProvider>().save(sale, id: _editId);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) {
      if (_reminderEnabled && _reminderAt != null) {
        await NotificationService.instance.scheduleReminder(
          id: result.id,
          title: 'Payment Reminder',
          body: '${result.customerName.isNotEmpty ? result.customerName : 'Customer'} '
              'owes ${Formatters.currency(result.dueAmount)}',
          scheduledDate: _reminderAt!,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reminder Set'),
            content: Text(
              'Reminder set for ${Formatters.date(_reminderAt)} at '
              '${TimeOfDay.fromDateTime(_reminderAt!).format(ctx)}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
            ],
          ),
        );
        if (!mounted) return;
      } else {
        // Editing a sale that previously had a reminder but it's now off —
        // don't leave a stale notification scheduled for it.
        await NotificationService.instance.cancel(result.id);
      }
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/invoice/${result.id}');
      }
    } else {
      final err = context.read<SaleProvider>().error;
      showAppSnackBar(context, err ?? 'Failed to save invoice', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editId != null ? 'Edit Invoice' : 'New Invoice'),
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
                        onTap: _pickCustomer,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Customer',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          child: Text(_customer?.name ?? 'Walk-in Customer'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _invoiceController,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Number',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DatePickerField(
                              label: 'Invoice Date',
                              date: _saleDate,
                              onPick: (d) => setState(() => _saleDate = d),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DatePickerField(
                              label: 'Due Date',
                              date: _dueDate,
                              onPick: (d) => setState(() => _dueDate = d),
                              optional: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Switch(
                                  value: _reminderEnabled,
                                  onChanged: (v) async {
                                    if (v) {
                                      final granted = await NotificationService.instance.requestPermission();
                                      if (!context.mounted) return;
                                      if (!granted) {
                                        showAppSnackBar(
                                          context,
                                          'Notifications are turned off for this app — enable them in phone settings to get reminders.',
                                          isError: true,
                                        );
                                        return;
                                      }
                                      _reminderAt ??= DateTime(
                                        (_dueDate ?? _saleDate).year,
                                        (_dueDate ?? _saleDate).month,
                                        (_dueDate ?? _saleDate).day,
                                        9,
                                      );
                                    }
                                    setState(() => _reminderEnabled = v);
                                  },
                                ),
                                const Text('Set Reminder', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          if (_reminderEnabled)
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final base = _reminderAt ?? (_dueDate ?? _saleDate);
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: base,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate == null || !context.mounted) return;
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(base),
                                  );
                                  if (pickedTime == null) return;
                                  setState(() {
                                    _reminderAt = DateTime(
                                      pickedDate.year, pickedDate.month, pickedDate.day,
                                      pickedTime.hour, pickedTime.minute,
                                    );
                                  });
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Remind me at', isDense: true),
                                  child: Text(
                                    _reminderAt != null
                                        ? '${Formatters.date(_reminderAt)} · ${TimeOfDay.fromDateTime(_reminderAt!).format(context)}'
                                        : 'Pick date & time',
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
                        (e) => _LineItemRow(
                          index: e.key + 1,
                          item: e.value,
                          onPickProduct: () => _pickProduct(e.value),
                          onRemove: _items.length > 1
                              ? () => setState(() => _items.removeAt(e.key))
                              : null,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _items.add(_LineItem())),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountPctController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Discount (%)',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_vatEnabled)
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: _taxRateController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'VAT %',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VAT',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Switch(
                                value: _vatEnabled,
                                activeThumbColor: AppColors.orange,
                                onChanged: (v) =>
                                    setState(() => _vatEnabled = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    title: 'Payment',
                    children: [
                      _totalsRow('Subtotal', _subtotal),
                      _totalsRow('Discount', -_discountAmount),
                      if (_vatEnabled) _totalsRow('VAT (${_taxRate.toStringAsFixed(_taxRate == _taxRate.roundToDouble() ? 0 : 2)}%)', _taxAmount),
                      const Divider(height: 20),
                      _totalsRow('Grand Total', _total, bold: true),
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
                            'Nothing collected yet — set a Due Date above so this shows up as overdue if unpaid.',
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
                              onChanged: (v) =>
                                  setState(() => _paymentMethod = v ?? 'CASH'),
                            ),
                          ),
                        ],
                      ),
                      // Only for non-cash methods, so the sale actually
                      // shows up on that account's Bank Statement instead
                      // of payment method being purely cosmetic.
                      if (_paymentMethod != 'CASH') ...[
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final bankAccounts = context
                                .watch<BankingProvider>()
                                .accounts
                                .where((a) => a.isActive)
                                .toList();
                            if (bankAccounts.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'No bank accounts yet — add one in Banking, or switch this to Cash.',
                                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                                ),
                              );
                            }
                            return DropdownButtonFormField<int>(
                              initialValue: bankAccounts.any((a) => a.id == _bankAccountId)
                                  ? _bankAccountId
                                  : null,
                              decoration: const InputDecoration(labelText: 'Account *'),
                              items: bankAccounts
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(
                                        a.bankName.isNotEmpty ? '${a.accountName} (${a.bankName})' : a.accountName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                          'Rest goes to the bank account above — ${Formatters.currency((_paid - _cashAmount).clamp(0, _paid))}',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _totalsRow(
                        _isAdvance ? 'Advance (Overpaid)' : 'Balance Due',
                        _isAdvance ? -_balanceDue : _balanceDue,
                        color: _balanceDue > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            bottom: false,
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
                      label: 'Confirm Invoice',
                      isLoading: _saving,
                      onPressed: () => _save('CONFIRMED'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const AppBottomNav(currentIndex: 1),
        ],
      ),
    );
  }

  Widget _totalsRow(
    String label,
    double value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontSize: bold ? 15 : 13,
            ),
          ),
          Text(
            Formatters.currency(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 13,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line item, laid out like a row of the printed invoice's item table
/// (S.N. / Name / Qty / Rate / Amount) — a numbered badge lines it up with
/// the product name, and Product/Qty/Price/Disc./Amount all share one row —
/// every column is [Expanded] with a fixed flex ratio (never a fixed pixel
/// width) so the row always fits without overflowing, the same way the web
/// item table's grid-cols-12 columns are proportional rather than fixed.
class _LineItemRow extends StatelessWidget {
  final int index;
  final _LineItem item;
  final VoidCallback onPickProduct;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _LineItemRow({
    required this.index,
    required this.item,
    required this.onPickProduct,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.navy50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.orangeDark,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: onPickProduct,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Product',
                  isDense: true,
                ),
                child: Text(
                  item.nameController.text.isEmpty
                      ? 'Select product'
                      : item.nameController.text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
          if (item.unitDetail?.hasSecondary == true) ...[
            const SizedBox(width: 4),
            _UnitToggle(item: item, onChanged: onChanged),
          ],
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(labelText: 'Price', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(labelText: 'Disc.', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(
              Formatters.currency(item.total),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 28,
            child: onRemove != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Small tappable chip that toggles a line item between its product's
/// primary and secondary unit (e.g. "Box" ↔ "Piece"), recomputing the
/// suggested price from the product's true base price each time (see
/// _LineItem.basePrice) so repeated toggling never compounds a conversion
/// on top of a previous one. Only rendered when the product actually has a
/// secondary unit configured — otherwise this column simply isn't there,
/// preserving the single-line layout for the common single-unit case.
class _UnitToggle extends StatelessWidget {
  final _LineItem item;
  final VoidCallback onChanged;

  const _UnitToggle({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final unit = item.unitDetail!;
    final currentLabel = item.unitLabel.isEmpty ? unit.name : item.unitLabel;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        final isSecondary =
            currentLabel.trim().toLowerCase() == unit.secondaryUnit.trim().toLowerCase();
        final newLabel = isSecondary ? unit.name : unit.secondaryUnit;
        item.unitLabel = newLabel;
        item.priceController.text = unit.priceFor(item.basePrice, newLabel).toString();
        onChanged();
      },
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          currentLabel,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.orangeDark,
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPick;
  final bool optional;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onPick,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(
          date != null ? Formatters.date(date) : (optional ? 'Not set' : '-'),
        ),
      ),
    );
  }
}
