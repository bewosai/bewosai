import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../providers/business_provider.dart';
import '../../widgets/app_widgets.dart';
import 'invoice_detail_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _sales = [];
  List _quotations = [];
  List _returns = [];
  bool _loading = true;
  String _search = '';

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
        biz.getSales(),
        biz.getSales(params: {'sale_type': 'QUOTATION'}),
        biz.getSalesReturns(),
      ]);
      _sales = results[0];
      _quotations = results[1];
      _returns = results[2];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('sales'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => setState(() => _search = _search.isEmpty ? ' ' : ''),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.navy500,
          indicatorColor: AppColors.orange,
          tabs: [
            Tab(text: settings.t('invoice')),
            Tab(text: settings.t('quotation')),
            Tab(text: settings.t('sales_return')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sales_fab',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateSaleSheet(context, settings),
        icon: const Icon(Icons.add_rounded),
        label: Text(settings.t('new_invoice')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _SalesList(
                  items: _sales,
                  settings: settings,
                  onRefresh: _fetch,
                  search: _search.trim(),
                ),
                _SalesList(
                  items: _quotations,
                  settings: settings,
                  onRefresh: _fetch,
                  search: _search.trim(),
                  isQuotation: true,
                ),
                _ReturnsList(
                  items: _returns,
                  settings: settings,
                  onRefresh: _fetch,
                ),
              ],
            ),
    );
  }

  void _showCreateSaleSheet(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CreateSaleSheet(
        settings: settings,
        biz: context.read<BusinessProvider>(),
        onCreated: _fetch,
      ),
    );
  }
}

class _SalesList extends StatelessWidget {
  final List items;
  final AppSettings settings;
  final VoidCallback onRefresh;
  final String search;
  final bool isQuotation;
  const _SalesList({
    required this.items,
    required this.settings,
    required this.onRefresh,
    this.search = '',
    this.isQuotation = false,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = search.isEmpty
        ? items
        : items
            .where((s) =>
                (s['invoice_number'] ?? '').toString().toLowerCase().contains(search.toLowerCase()) ||
                (s['party_name'] ?? '').toString().toLowerCase().contains(search.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        message: settings.t('no_data'),
        action: TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final s = filtered[i];
          final status = s['status'] ?? 'DRAFT';
          final amount = double.tryParse(s['total']?.toString() ?? '0') ?? 0;
          final paid = double.tryParse(s['paid_amount']?.toString() ?? '0') ?? 0;
          final balance = amount - paid;

          return AppCard(
            onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(
                  sale: Map<String, dynamic>.from(s as Map)),
            )),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['invoice_number'] ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s['party_name'] ?? settings.t('customer'),
                          style: TextStyle(
                              fontSize: 13, color: AppColors.navy500),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: status),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _InfoChip(
                      label: settings.t('total'),
                      value: settings.formatAmount(amount),
                      color: AppColors.navy800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoChip(
                      label: settings.t('paid'),
                      value: settings.formatAmount(paid),
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoChip(
                      label: settings.t('balance'),
                      value: settings.formatAmount(balance),
                      color: balance > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  s['sale_date'] ?? '',
                  style: TextStyle(fontSize: 11, color: AppColors.navy500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

class _ReturnsList extends StatelessWidget {
  final List items;
  final AppSettings settings;
  final VoidCallback onRefresh;
  const _ReturnsList(
      {required this.items,
      required this.settings,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_return_rounded,
        message: settings.t('no_data'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final r = items[i];
        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment_return_rounded,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Return for ${r['invoice_number'] ?? '#${r['id']}'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(r['return_date'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.navy500)),
                ],
              ),
            ),
            Text(
              settings.formatAmount(
                  double.tryParse(r['amount']?.toString() ?? '0') ?? 0),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.error),
            ),
          ]),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.navy500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _CreateSaleSheet extends StatefulWidget {
  final AppSettings settings;
  final BusinessProvider biz;
  final VoidCallback onCreated;
  const _CreateSaleSheet(
      {required this.settings, required this.biz, required this.onCreated});

  @override
  State<_CreateSaleSheet> createState() => _CreateSaleSheetState();
}

class _CreateSaleSheetState extends State<_CreateSaleSheet> {
  final _notesCtrl    = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl     = TextEditingController(text: '0');
  String _paymentMethod = 'CASH';
  String _status = 'CONFIRMED';
  double _taxRate = 0;   // 0 or 13 (Nepal VAT)
  bool _saving = false;
  final List<Map<String, dynamic>> _items = [];

  // Party selection
  int? _selectedCustomerId;
  List<Map<String, dynamic>> _customers = [];

  // Product list for picker
  List<Map<String, dynamic>> _products = [];

  static const _draftKey = 'sale_draft';

  @override
  void initState() {
    super.initState();
    _loadData();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || !mounted) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _selectedCustomerId = d['customer'] as int?;
        _paymentMethod      = d['payment_method']?.toString() ?? 'CASH';
        _status             = d['status']?.toString() ?? 'CONFIRMED';
        _taxRate            = (d['tax_rate'] as num?)?.toDouble() ?? 0;
        _discountCtrl.text  = d['discount']?.toString() ?? '0';
        _paidCtrl.text      = d['paid']?.toString() ?? '0';
        _notesCtrl.text     = d['notes']?.toString() ?? '';
        final rawItems = d['items'] as List?;
        if (rawItems != null) {
          _items
            ..clear()
            ..addAll(rawItems.map((i) => Map<String, dynamic>.from(i as Map)));
        }
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode({
        'customer':       _selectedCustomerId,
        'payment_method': _paymentMethod,
        'status':         _status,
        'tax_rate':       _taxRate,
        'discount':       _discountCtrl.text,
        'paid':           _paidCtrl.text,
        'notes':          _notesCtrl.text,
        'items':          _items,
      }));
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.biz.getParties(partyType: 'CUSTOMER'),
        widget.biz.getProducts(),
      ]);
      if (mounted) setState(() {
        _customers = results[0];
        _products  = results[1];
      });
    } catch (_) {}
  }

  void _addItem() {
    setState(() => _items.add({
          'product_name': '',
          'product': null,
          'quantity': 1.0,
          'unit_price': 0.0,
          'discount_amount': 0.0,
        }));
    _saveDraft();
  }

  double get _subtotal =>
      _items.fold(0.0, (s, i) =>
          s + ((i['quantity'] as num).toDouble() * (i['unit_price'] as num).toDouble())
            - (i['discount_amount'] as num? ?? 0).toDouble());

  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _taxable  => (_subtotal - _discount).clamp(0, double.infinity);
  double get _taxAmt   => _taxable * _taxRate / 100;
  double get _total    => _taxable + _taxAmt;

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    try {
      final paid = double.tryParse(_paidCtrl.text) ?? 0;
      await widget.biz.createSale({
        if (_selectedCustomerId != null) 'customer': _selectedCustomerId,
        'sale_date': DateTime.now().toIso8601String().substring(0, 10),
        'payment_method': _paymentMethod,
        'status': _status,
        'subtotal': _subtotal,
        'discount': _discount,
        'tax_rate': _taxRate,
        'paid_amount': paid > _total ? _total : paid,
        'notes': _notesCtrl.text.trim(),
        'items': _items.map((i) => {
          'product_name': i['product_name'],
          'quantity': i['quantity'],
          'unit_price': i['unit_price'],
          'discount_amount': i['discount_amount'] ?? 0,
        }).toList(),
      });
      if (mounted) {
        await _clearDraft();
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.errorMessage(e))),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return DraggableScrollableSheet(
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
          Text(s.t('new_invoice'),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          DropdownButtonFormField<int?>(
            value: _selectedCustomerId,
            decoration: InputDecoration(
              labelText: s.t('customer'),
              prefixIcon: const Icon(Icons.person_rounded),
              hintText: 'Walk-in customer',
            ),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Walk-in Customer')),
              ..._customers.map((p) => DropdownMenuItem<int?>(
                    value: p['id'] as int?,
                    child: Text(p['name']?.toString() ?? ''),
                  )),
            ],
            onChanged: (v) { setState(() => _selectedCustomerId = v); _saveDraft(); },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'CASH',   child: Text('Cash')),
              DropdownMenuItem(value: 'BANK',   child: Text('Bank')),
              DropdownMenuItem(value: 'ESEWA',  child: Text('eSewa')),
              DropdownMenuItem(value: 'KHALTI', child: Text('Khalti')),
            ],
            onChanged: (v) { setState(() => _paymentMethod = v!); _saveDraft(); },
          ),
          const SizedBox(height: 12),
          // VAT toggle — Nepal 13%
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_outlined, size: 18, color: AppColors.navy500),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VAT 13%', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Nepal VAT (${_taxRate == 13 ? "applied" : "not applied"})',
                    style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
              ])),
              Switch.adaptive(
                value: _taxRate == 13,
                activeColor: AppColors.orange,
                onChanged: (v) { setState(() => _taxRate = v ? 13 : 0); _saveDraft(); },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: _discountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Discount (Rs.)', prefixIcon: Icon(Icons.discount_outlined)),
              onChanged: (_) { setState(() {}); _saveDraft(); },
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _paidCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Paid Amount', prefixIcon: Icon(Icons.payments_outlined)),
              onChanged: (_) { setState(() {}); _saveDraft(); },
            )),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
              DropdownMenuItem(value: 'DRAFT',     child: Text('Draft')),
            ],
            onChanged: (v) { setState(() => _status = v!); _saveDraft(); },
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(
                child: Text('Items',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Item'),
            ),
          ]),
          ..._items.asMap().entries.map((e) => _ItemRow(
                index: e.key,
                item: e.value,
                settings: s,
                products: _products,
                onUpdate: (k, v) { setState(() => _items[e.key][k] = v); _saveDraft(); },
                onRemove: () { setState(() => _items.removeAt(e.key)); _saveDraft(); },
              )),
          if (_items.isNotEmpty) ...[
            const Divider(height: 24),
            if (_discount > 0)
              _summaryRow('Subtotal', _subtotal, AppColors.navy500, s),
            if (_discount > 0)
              _summaryRow('Discount', -_discount, AppColors.error, s),
            if (_taxRate > 0)
              _summaryRow('VAT ${_taxRate.toInt()}%', _taxAmt, AppColors.warning, s),
            const Divider(height: 12),
            _summaryRow(s.t('total'), _total, AppColors.orange, s, large: true),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(labelText: s.t('notes')),
            maxLines: 2,
            onChanged: (_) => _saveDraft(),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: s.t('save'),
            onPressed: _save,
            loading: _saving,
            icon: Icons.check_rounded,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

Widget _summaryRow(String label, double value, Color color, AppSettings s,
    {bool large = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label,
          style: TextStyle(fontSize: large ? 15 : 13,
              fontWeight: large ? FontWeight.w800 : FontWeight.w500,
              color: large ? color : AppColors.navy500))),
      Text(s.formatAmount(value.abs()),
          style: TextStyle(fontSize: large ? 18 : 14,
              fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _ItemRow extends StatefulWidget {
  final int index;
  final Map<String, dynamic> item;
  final AppSettings settings;
  final List<Map<String, dynamic>> products;
  final Function(String, dynamic) onUpdate;
  final VoidCallback onRemove;
  const _ItemRow({
    required this.index,
    required this.item,
    required this.settings,
    required this.products,
    required this.onUpdate,
    required this.onRemove,
  });
  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.item['product_name']?.toString() ?? '');
    _qtyCtrl   = TextEditingController(text: (widget.item['quantity'] ?? 1).toString());
    _priceCtrl = TextEditingController(text: (widget.item['unit_price'] ?? 0.0).toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _pickProduct(BuildContext ctx) {
    if (widget.products.isEmpty) return;
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductPickerSheet(
        products: widget.products,
        settings: widget.settings,
        onPick: (p) {
          final price = double.tryParse(
              p['sale_price']?.toString() ?? p['selling_price']?.toString() ?? '0') ?? 0;
          final name = p['name']?.toString() ?? '';
          final id   = p['id'];
          _nameCtrl.text  = name;
          _priceCtrl.text = price.toString();
          widget.onUpdate('product_name', name);
          widget.onUpdate('product', id);
          widget.onUpdate('unit_price', price);
          setState(() {});
        },
      ),
    );
  }

  double get _lineTotal {
    final qty   = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    return qty * price;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.products.isNotEmpty ? () => _pickProduct(context) : null,
                child: AbsorbPointer(
                  absorbing: widget.products.isNotEmpty,
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: widget.products.isNotEmpty
                          ? 'Tap to pick product'
                          : 'Product name',
                      isDense: true,
                      border: InputBorder.none,
                      suffixIcon: widget.products.isNotEmpty
                          ? const Icon(Icons.arrow_drop_down_rounded,
                              size: 20, color: AppColors.navy500)
                          : null,
                    ),
                    onChanged: (v) => widget.onUpdate('product_name', v),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: widget.onRemove,
            ),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(
                    labelText: 'Qty', isDense: true, border: InputBorder.none),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  widget.onUpdate('quantity', double.tryParse(v) ?? 1);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                    labelText: 'Price', isDense: true, border: InputBorder.none),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  widget.onUpdate('unit_price', double.tryParse(v) ?? 0);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '= ${widget.settings.formatAmount(_lineTotal)}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.orange),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final AppSettings settings;
  final void Function(Map<String, dynamic>) onPick;
  const _ProductPickerSheet({required this.products, required this.settings, required this.onPick});
  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? widget.products
        : widget.products.where((p) =>
            (p['name'] ?? '').toString().toLowerCase().contains(_q.toLowerCase()) ||
            (p['barcode'] ?? '').toString().toLowerCase().contains(_q.toLowerCase())).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(height: 4, width: 40, decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Search product…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                final price = double.tryParse(
                    p['sale_price']?.toString() ?? p['selling_price']?.toString() ?? '0') ?? 0;
                final stock = double.tryParse(p['stock_quantity']?.toString() ?? '0') ?? 0;
                final unit  = p['unit_name']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  title: Text(p['name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('${widget.settings.formatAmount(price)}  ·  Stock: $stock $unit',
                      style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
                  trailing: const Icon(Icons.add_circle_rounded, color: AppColors.orange, size: 20),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPick(p);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
