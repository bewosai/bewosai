import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/notifications/notification_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../shared/widgets/app_date_picker.dart';
import '../../../../../shared/widgets/app_widgets.dart';
import '../../../../../shared/widgets/line_discount_field.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../banking/presentation/providers/banking_provider.dart';
import '../../../../inventory/data/models/inventory_model.dart';
import '../../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../../parties/data/models/party_model.dart';
import '../../../../parties/presentation/providers/party_provider.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/services/sale_service.dart';
import '../../providers/sale_provider.dart';
import '../../../../../core/calendar/nepal_time.dart';

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
  final qtyController = TextEditingController(text: '0');
  final priceController = TextEditingController(text: '0');
  final discountController = TextEditingController(text: '0');

  double get qty => double.tryParse(qtyController.text) ?? 0;
  double get price => double.tryParse(priceController.text) ?? 0;
  double get discount => Validators.cappedDiscount(discountController.text, qty * price);
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
  DateTime _saleDate = NepalTime.now();
  DateTime? _dueDate;
  String _paymentMethod = 'CASH';
  int? _bankAccountId;
  bool _vatEnabled = false;
  // Separate from _paymentMethod (which channel it'll settle through) —
  // Credit means nothing is collected today regardless of method. Only
  // snaps Amount Paid to the current total/zero the moment it's tapped,
  // not continuously kept in sync as items change afterward.
  bool _creditSale = false;
  // Whether the invoice-level Discount field holds a flat amount (Rs) rather
  // than a percentage of the subtotal.
  bool _discountIsAmount = false;
  bool _saving = false;
  bool _loaded = false;
  int? _editId;
  bool _isPendingEdit = false;
  bool _reminderEnabled = false;
  DateTime? _reminderAt;
  final _reminderNoteController = TextEditingController();

  // Starts empty: an item only lands here once picked and confirmed in the
  // item-detail sheet (see _pickProduct / _showItemDetailSheet), so there's
  // never a blank half-filled row to fix up.
  final List<_LineItem> _items = [];

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
    _saleDate = sale.saleDate ?? NepalTime.now();
    _dueDate = sale.dueDate;
    _paymentMethod = sale.paymentMethod;
    _bankAccountId = sale.bankAccount;
    _vatEnabled = sale.taxRate > 0;
    _reminderEnabled = sale.reminderEnabled;
    _reminderAt = sale.reminderAt;
    _reminderNoteController.text = sale.reminderNote;
    if (sale.taxRate > 0) {
      _taxRateController.text = sale.taxRate == sale.taxRate.roundToDouble()
          ? sale.taxRate.toStringAsFixed(0)
          : sale.taxRate.toString();
    }
    _paidController.text = sale.paidAmount.toString();
    _cashAmountController.text = sale.cashAmount.toString();
    _creditSale = sale.dueAmount > 0;
    _notesController.text = sale.notes;
    // Shown as the exact saved amount: converting to a rounded percentage and
    // back would nudge the discount by a few paisa each time it's re-saved.
    _discountIsAmount = sale.discount > 0;
    _discountPctController.text = sale.discount > 0 ? _fmtNumber(sale.discount) : '0';
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
    _reminderNoteController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.total);
  double get _discountValue => double.tryParse(_discountPctController.text) ?? 0;
  // The single discount field is either a percentage of the subtotal or a
  // flat amount (_discountIsAmount); either way it's capped to [0, subtotal]
  // so a typo can't push the taxable amount negative.
  double get _discountAmount {
    final raw = _discountIsAmount ? _discountValue : _subtotal * _discountValue / 100;
    return raw.clamp(0, _subtotal).toDouble();
  }

  static String _fmtNumber(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Switches the discount between % and a flat amount, converting the value
  /// already typed so the discount itself doesn't change — only how it's shown.
  void _setDiscountMode(bool asAmount) {
    if (asAmount == _discountIsAmount) return;
    final current = _discountAmount;
    setState(() {
      _discountIsAmount = asAmount;
      _discountPctController.text = current == 0
          ? '0'
          : asAmount
              ? _fmtNumber(current)
              : _fmtNumber(_subtotal > 0 ? current / _subtotal * 100 : 0);
    });
  }
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
        // Same category/stock/price layout as the Inventory list, so the
        // user can see what they're picking (and whether it's low on
        // stock) without leaving the invoice to go check.
        detailBuilder: (ctx, p) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${p.categoryName.isEmpty ? 'Uncategorized' : p.categoryName} · ${p.unitName}',
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
                  Formatters.currency(p.salePrice),
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

  /// Shown right after a product is picked (or newly created) — the
  /// product's own detail (category, unit, stock, price) plus editable
  /// Quantity/Price/Discount and a live total, so the user reviews and sets
  /// those before the item actually lands on the invoice, instead of it
  /// appearing with a bare "0" quantity they then have to notice and fix
  /// inline in the cramped line-item row.
  void _showItemDetailSheet(_LineItem item, Product p, {bool showStock = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ItemDetailSheet(
        product: p,
        initialQty: item.product == p.id && item.qty > 0 ? item.qty : 1,
        initialPrice: item.product == p.id && item.price > 0 ? item.price : p.salePrice,
        initialDiscount: item.product == p.id ? item.discount : 0,
        initialUnitLabel: item.product == p.id ? item.unitLabel : '',
        showStock: showStock,
        onAdd: (qty, price, discount, unitLabel) {
          setState(() {
            // A stand-in product (id 0) must not overwrite the line's real link.
            if (p.id != 0) item.product = p.id;
            item.nameController.text = p.name;
            item.unitDetail = p.unitDetail;
            item.unitLabel = unitLabel;
            item.basePrice = p.salePrice;
            item.qtyController.text = qty.toString();
            item.priceController.text = price.toString();
            item.discountController.text = discount.toString();
            if (!_items.contains(item)) _items.add(item);
          });
        },
      ),
    );
  }

  /// Re-opens the same detail sheet used when adding, pre-filled from the line,
  /// so editing and adding always look and behave identically.
  void _editItem(_LineItem item) {
    final match = context.read<InventoryProvider>().products.where((p) => p.id == item.product);
    if (match.isNotEmpty) {
      _showItemDetailSheet(item, match.first);
      return;
    }
    // The product record isn't loaded (or it's a free-text line): edit from
    // what the line itself remembers.
    _showItemDetailSheet(
      item,
      Product(
        id: item.product ?? 0,
        name: item.nameController.text,
        categoryName: '',
        unitName: item.unitLabel,
        unitDetail: item.unitDetail,
        description: '',
        purchasePrice: 0,
        salePrice: item.basePrice > 0 ? item.basePrice : item.price,
        stockQuantity: 0,
        lowStockThreshold: 0,
        isLowStock: false,
        barcode: '',
        isActive: true,
      ),
      showStock: false,
    );
  }

  bool get _hasContent =>
      _items.isNotEmpty ||
      _customer != null ||
      _discountValue > 0 ||
      _notesController.text.trim().isNotEmpty ||
      (double.tryParse(_paidController.text) ?? 0) > 0;

  /// Empties the invoice for a fresh start. Only offered for a new invoice —
  /// clearing one that's being edited would wipe what's saved (Back is the way out).
  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear invoice?'),
        content: const Text('All items and details on this invoice will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final removed = List<_LineItem>.of(_items);
    setState(() {
      _items.clear();
      _customer = null;
      _discountPctController.text = '0';
      _discountIsAmount = false;
      _paidController.text = '0';
      _cashAmountController.text = '0';
      _notesController.clear();
      _paymentMethod = 'CASH';
      _bankAccountId = null;
      _creditSale = false;
      _dueDate = null;
      _reminderEnabled = false;
      _reminderAt = null;
      _reminderNoteController.clear();
      _saleDate = NepalTime.now();
    });
    // Dispose after the frame that stops showing them, not during it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final i in removed) {
        i.dispose();
      }
    });
  }

  /// Removes a line, with a one-tap Undo so an accidental tap costs nothing.
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
    // No customer = a Cash Sale, which has to be paid in full: a balance due (or
    // an overpayment) with nobody attached would never appear as anyone's
    // To Receive / To Give. A draft isn't final yet, so it's exempt.
    if (status == 'CONFIRMED' && _customer == null && _balanceDue.abs() > 0.005) {
      showAppSnackBar(
        context,
        'A Cash Sale must be paid in full. Select a customer to leave a balance due.',
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
      reminderNote: _reminderEnabled ? _reminderNoteController.text.trim() : '',
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
        final note = _reminderNoteController.text.trim();
        final who = result.customerName.isNotEmpty ? result.customerName : 'Customer';
        await NotificationService.instance.scheduleReminder(
          id: result.id,
          title: 'Payment Reminder',
          body: '$who owes ${Formatters.currency(result.dueAmount)}${note.isEmpty ? '' : ' — $note'}',
          scheduledDate: _reminderAt!,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reminder Set'),
            content: Text(
              'Reminder set for ${Formatters.date(_reminderAt)} at '
              '${TimeOfDay.fromDateTime(_reminderAt!).format(ctx)}'
              '${note.isEmpty ? '' : '\n\n"$note"'}',
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
        actions: [
          if (_editId == null && _hasContent)
            IconButton(
              tooltip: 'Clear invoice',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClear,
            ),
          const HomeLogoButton(),
        ],
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
                          child: Text(_customer?.name ?? 'Cash Sales'),
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
                                  final pickedDate = await AppDatePicker.pick(
                                    context,
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
                      // What this reminder is actually for — a bare due-amount
                      // notification with no context is easy to ignore or
                      // misread days later ("owes Rs 2,000" — for what, again?).
                      if (_reminderEnabled) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reminderNoteController,
                          decoration: const InputDecoration(
                            labelText: 'Reminder note (optional)',
                            hintText: 'e.g. Promised to pay by Friday',
                            isDense: true,
                          ),
                          maxLength: 200,
                        ),
                      ],
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
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        // Opens the product dropdown straight away; the item is
                        // only added to the invoice once confirmed in the detail
                        // sheet, so cancelling leaves nothing behind.
                        onPressed: () => _pickProduct(_LineItem()),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    title: 'Discount & Tax',
                    children: [
                      // A % vs a flat Rs amount look identical while typing (both are
                      // just a number), so the two modes are laid out as a clearly
                      // separated toggle above the field, not squeezed onto the same
                      // line as the field itself — and Wrap (not Row) so long text or a
                      // narrow/small phone folds the second chip below instead of
                      // clipping or overflowing it off the edge of the screen.
                      Text('Discount as', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('% of total'),
                            selected: !_discountIsAmount,
                            selectedColor: AppColors.orangeLight,
                            onSelected: (_) => _setDiscountMode(false),
                          ),
                          ChoiceChip(
                            label: const Text('Flat Amount (Rs)'),
                            selected: _discountIsAmount,
                            selectedColor: AppColors.orangeLight,
                            onSelected: (_) => _setDiscountMode(true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _discountPctController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: _discountIsAmount ? 'Discount amount' : 'Discount percent',
                          prefixText: _discountIsAmount ? 'Rs ' : null,
                          suffixText: _discountIsAmount ? null : '%',
                          // Whichever mode is picked, show the other one's equivalent too,
                          // so "20%" and "Rs 200 off a Rs 1000 subtotal" are never ambiguous.
                          helperText: _subtotal > 0 && _discountAmount > 0
                              ? _discountIsAmount
                                  ? '= ${(_discountAmount / _subtotal * 100).toStringAsFixed(1)}% of Rs ${_subtotal.toStringAsFixed(0)}'
                                  : '= ${Formatters.currency(_discountAmount)} off Rs ${_subtotal.toStringAsFixed(0)}'
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const Divider(height: 28),
                      // VAT gets its own row — a toggle on the left, its rate field
                      // (only shown once VAT is on) on the right, each with room to
                      // breathe instead of being crammed in next to the discount field.
                      Row(
                        children: [
                          Expanded(
                            child: Text('Apply VAT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          Switch(
                            value: _vatEnabled,
                            activeThumbColor: AppColors.orange,
                            onChanged: (v) => setState(() => _vatEnabled = v),
                          ),
                        ],
                      ),
                      if (_vatEnabled) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: _taxRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'VAT rate', suffixText: '%'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 16),
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

/// Shown right after a product is picked — its own detail (category, unit,
/// stock, price) alongside editable Quantity/Price/Discount and a live
/// total, so mistakes (forgetting to set a quantity, a price that doesn't
/// look right) are caught here instead of after the item is already sitting
/// in the invoice's compact line-item row.
class _ItemDetailSheet extends StatefulWidget {
  final Product product;
  final double initialQty;
  final double initialPrice;
  final double initialDiscount;
  /// The unit this line is billed in (e.g. "Piece" vs the product's primary
  /// "Box"); blank means the primary unit.
  final String initialUnitLabel;
  /// False when [product] is only a stand-in built from an existing line (its
  /// real record isn't loaded), so a made-up "0 in stock" isn't shown.
  final bool showStock;
  final void Function(double qty, double price, double discount, String unitLabel) onAdd;

  const _ItemDetailSheet({
    required this.product,
    required this.initialQty,
    required this.initialPrice,
    required this.initialDiscount,
    required this.onAdd,
    this.initialUnitLabel = '',
    this.showStock = true,
  });

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  static String _clean(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  final _formKey = GlobalKey<FormState>();
  late final _qtyController = TextEditingController(text: _clean(widget.initialQty));
  late final _priceController = TextEditingController(text: _clean(widget.initialPrice));
  late final _discountController = TextEditingController(
    text: widget.initialDiscount == 0 ? '' : _clean(widget.initialDiscount),
  );

  late String _unitLabel = _resolveUnit();
  // Whether the Discount field holds a % of the line rather than rupees.
  bool _discountIsPercent = false;

  // The dropdown asserts its value is exactly one of its items, and a saved
  // line's unit label can differ in case/spacing (Unit.priceFor compares
  // case-insensitively for the same reason) — snap to the real unit name.
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
  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _discount =>
      Validators.discountAmount(_discountController.text, _qty * _price, percent: _discountIsPercent);
  double get _total => (_qty * _price) - _discount;
  double _priceFor(String label) => widget.product.unitDetail!
      .priceFor(widget.product.salePrice, label, secondaryPrice: widget.product.secondarySalePrice);

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
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
                // A separate row (rather than crammed alongside the category
                // text above) with Flexible on the stock side so a long
                // product/unit name wraps or ellipsizes instead of pushing
                // the price off-screen or overflowing the sheet.
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
                      Formatters.currency(p.salePrice),
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Only for products that have a secondary unit (e.g. Box/Piece):
                // switching recomputes the price from the product's base price
                // each time, so toggling back and forth never compounds.
                if (p.unitDetail?.hasSecondary == true) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _unitLabel,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [p.unitDetail!.name, p.unitDetail!.secondaryUnit]
                        .map((label) => DropdownMenuItem(
                              value: label,
                              child: Text('$label — ${Formatters.currency(_priceFor(label))}'),
                            ))
                        .toList(),
                    onChanged: (label) {
                      if (label == null || label == _unitLabel) return;
                      setState(() {
                        _unitLabel = label;
                        _priceController.text = _clean(_priceFor(label));
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
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price *'),
                        validator: (v) =>
                            Validators.required(v, 'Price') ?? Validators.positiveNumber(v, 'Price'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LineDiscountField(
                  controller: _discountController,
                  isPercent: _discountIsPercent,
                  gross: _qty * _price,
                  onModeChanged: (percent) => setState(() => _discountIsPercent = percent),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
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
                        label: 'Add to Invoice',
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) return;
                          widget.onAdd(_qty, _price, _discount, _unitLabel);
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

/// One invoice line as a compact box showing only what matters — name,
/// quantity x price, any discount and the line total — with edit and delete
/// side by side. Editing (tap anywhere, or the pencil) opens the same detail
/// sheet used to add the item, so what you see here is exactly what you set
/// there.
class _LineItemRow extends StatelessWidget {
  final int index;
  final _LineItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _LineItemRow({
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
        final picked = await AppDatePicker.pick(
          context,
          initialDate: date ?? NepalTime.now(),
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
