import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
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
                (s['bill_number'] ?? '').toString().toLowerCase().contains(search.toLowerCase()) ||
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
          final amount = double.tryParse(s['total_amount']?.toString() ?? '0') ?? 0;
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
                          s['bill_number'] ?? '—',
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
                  s['date'] ?? '',
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
                  Text(r['return_number'] ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(r['party_name'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.navy500)),
                ],
              ),
            ),
            Text(
              settings.formatAmount(
                  double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0),
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
  final _partyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMode = 'CASH';
  String _status = 'CONFIRMED';
  bool _saving = false;
  final List<Map<String, dynamic>> _items = [];

  void _addItem() {
    setState(() => _items.add({
          'product_name': '',
          'quantity': 1,
          'unit_price': 0.0,
        }));
  }

  double get _total =>
      _items.fold(0, (s, i) => s + (i['quantity'] as int) * (i['unit_price'] as double));

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.biz.createSale({
        'party_name': _partyCtrl.text.trim(),
        'payment_mode': _paymentMode,
        'status': _status,
        'notes': _notesCtrl.text.trim(),
        'items': _items,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
          TextField(
            controller: _partyCtrl,
            decoration: InputDecoration(
              labelText: s.t('customer'),
              prefixIcon: const Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 12),
          // Payment mode
          DropdownButtonFormField<String>(
            value: _paymentMode,
            decoration: InputDecoration(labelText: 'Payment Mode'),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
            ],
            onChanged: (v) => setState(() => _paymentMode = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
              DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
            ],
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(
                child: Text('Items',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700))),
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
                onUpdate: (k, v) => setState(() => _items[e.key][k] = v),
                onRemove: () => setState(() => _items.removeAt(e.key)),
              )),
          if (_items.isNotEmpty) ...[
            const Divider(height: 24),
            Row(children: [
              Expanded(
                  child: Text(s.t('total'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
              Text(s.formatAmount(_total),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.orange)),
            ]),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(labelText: s.t('notes')),
            maxLines: 2,
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

class _ItemRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final AppSettings settings;
  final Function(String, dynamic) onUpdate;
  final VoidCallback onRemove;
  const _ItemRow({
    required this.index,
    required this.item,
    required this.settings,
    required this.onUpdate,
    required this.onRemove,
  });

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
        children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: item['product_name'],
                decoration: const InputDecoration(
                    hintText: 'Product name',
                    isDense: true,
                    border: InputBorder.none),
                onChanged: (v) => onUpdate('product_name', v),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.error),
              onPressed: onRemove,
            ),
          ]),
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: item['quantity'].toString(),
                decoration: const InputDecoration(
                    hintText: 'Qty',
                    isDense: true,
                    border: InputBorder.none),
                keyboardType: TextInputType.number,
                onChanged: (v) => onUpdate('quantity', int.tryParse(v) ?? 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: item['unit_price'].toString(),
                decoration: const InputDecoration(
                    hintText: 'Unit price',
                    isDense: true,
                    border: InputBorder.none),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    onUpdate('unit_price', double.tryParse(v) ?? 0),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
