import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../providers/business_provider.dart';
import '../../widgets/app_widgets.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _purchases = [];
  List _returns = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
        biz.getPurchases(),
        biz.getPurchaseReturns(),
      ]);
      _purchases = results[0];
      _returns   = results[1];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    final filtered = _search.isEmpty
        ? _purchases
        : _purchases.where((p) {
            final q = _search.toLowerCase();
            return (p['bill_number'] ?? '').toString().toLowerCase().contains(q) ||
                (p['supplier_name'] ?? '').toString().toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('purchases'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.navy500,
          indicatorColor: AppColors.orange,
          tabs: const [
            Tab(text: 'Bills'),
            Tab(text: 'Returns'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'purchases_fab',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () {
          if (_tabs.index == 0) {
            _showCreatePurchaseSheet(context, settings);
          } else {
            _showCreateReturnSheet(context, settings);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: AnimatedBuilder(
          animation: _tabs,
          builder: (_, __) => Text(
              _tabs.index == 0 ? settings.t('new_purchase') : 'New Return'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                // ── Bills Tab ──────────────────────────────────────────────
                Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: settings.t('search'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.local_shipping_rounded,
                            message: settings.t('no_data'),
                            action: TextButton.icon(
                              onPressed: _fetch,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async => _fetch(),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _buildPurchaseCard(filtered[i], settings),
                            ),
                          ),
                  ),
                ]),

                // ── Returns Tab ────────────────────────────────────────────
                _returns.isEmpty
                    ? EmptyState(
                        icon: Icons.assignment_return_rounded,
                        message: 'No purchase returns yet',
                        action: TextButton.icon(
                          onPressed: _fetch,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _fetch(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _returns.length,
                          itemBuilder: (_, i) => _buildReturnCard(_returns[i], settings),
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _buildPurchaseCard(Map p, AppSettings settings) {
    final amount = double.tryParse(p['total']?.toString() ?? p['total_amount']?.toString() ?? '0') ?? 0;
    final paid   = double.tryParse(p['paid_amount']?.toString() ?? '0') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_shipping_rounded,
                  color: AppColors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['bill_number'] ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(p['supplier_name'] ?? settings.t('supplier'),
                  style: const TextStyle(fontSize: 12, color: AppColors.navy500)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(settings.formatAmount(amount),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (amount - paid > 0)
                Text('Due: ${settings.formatAmount(amount - paid)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.error)),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.navy500),
            const SizedBox(width: 4),
            Text(p['date'] ?? p['purchase_date'] ?? '',
                style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
            const Spacer(),
            StatusBadge(status: p['status'] ?? 'CONFIRMED'),
          ]),
        ]),
      ),
    );
  }

  Widget _buildReturnCard(Map r, AppSettings settings) {
    final amount   = double.tryParse(r['amount']?.toString() ?? '0') ?? 0;
    final reason   = r['reason'] as String? ?? '';
    final date     = r['return_date'] as String? ?? '';
    final billNo   = r['original_purchase_number'] as String?
        ?? r['original_purchase']?.toString() ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_return_rounded,
                color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Return for $billNo',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (reason.isNotEmpty)
              Text(reason,
                  style: const TextStyle(fontSize: 12, color: AppColors.navy500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            if (date.isNotEmpty)
              Text(date, style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
          ])),
          Text(settings.formatAmount(amount),
              style: const TextStyle(fontWeight: FontWeight.w800,
                  color: AppColors.warning, fontSize: 15)),
        ]),
      ),
    );
  }

  void _showCreatePurchaseSheet(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CreatePurchaseSheet(
        settings: settings,
        biz: context.read<BusinessProvider>(),
        onCreated: _fetch,
      ),
    );
  }

  void _showCreateReturnSheet(BuildContext context, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CreateReturnSheet(
        settings: settings,
        biz: context.read<BusinessProvider>(),
        purchases: _purchases,
        onCreated: _fetch,
      ),
    );
  }
}

// ─── Create Purchase Sheet ────────────────────────────────────────────────────

class _CreatePurchaseSheet extends StatefulWidget {
  final AppSettings settings;
  final BusinessProvider biz;
  final VoidCallback onCreated;
  const _CreatePurchaseSheet({required this.settings, required this.biz, required this.onCreated});

  @override
  State<_CreatePurchaseSheet> createState() => _CreatePurchaseSheetState();
}

class _CreatePurchaseSheetState extends State<_CreatePurchaseSheet> {
  final _supplierCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _paymentMode = 'CASH';
  bool _saving = false;
  final List<Map<String, dynamic>> _items = [];

  double get _total =>
      _items.fold(0, (s, i) => s + (i['quantity'] as int) * (i['unit_price'] as double));

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
          Center(child: Container(
              height: 4, width: 40, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)))),
          Text(s.t('new_purchase'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          TextField(
            controller: _supplierCtrl,
            decoration: InputDecoration(
              labelText: s.t('supplier'),
              prefixIcon: const Icon(Icons.business_rounded),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentMode,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'CASH',   child: Text('Cash')),
              DropdownMenuItem(value: 'BANK',   child: Text('Bank')),
              DropdownMenuItem(value: 'ESEWA',  child: Text('eSewa')),
              DropdownMenuItem(value: 'KHALTI', child: Text('Khalti')),
            ],
            onChanged: (v) => setState(() => _paymentMode = v!),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Text('Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(
                  {'product_name': '', 'quantity': 1, 'unit_price': 0.0})),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Item'),
            ),
          ]),
          ..._items.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Expanded(child: TextFormField(
                    initialValue: e.value['product_name'],
                    decoration: const InputDecoration(
                        hintText: 'Product', isDense: true, border: InputBorder.none),
                    onChanged: (v) => setState(() => _items[e.key]['product_name'] = v),
                  )),
                  SizedBox(width: 60, child: TextFormField(
                    initialValue: e.value['quantity'].toString(),
                    decoration: const InputDecoration(
                        hintText: 'Qty', isDense: true, border: InputBorder.none),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() =>
                        _items[e.key]['quantity'] = int.tryParse(v) ?? 1),
                  )),
                  SizedBox(width: 80, child: TextFormField(
                    initialValue: e.value['unit_price'].toString(),
                    decoration: const InputDecoration(
                        hintText: 'Price', isDense: true, border: InputBorder.none),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() =>
                        _items[e.key]['unit_price'] = double.tryParse(v) ?? 0),
                  )),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                    onPressed: () => setState(() => _items.removeAt(e.key)),
                  ),
                ]),
              )),
          if (_items.isNotEmpty) ...[
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text(s.t('total'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              Text(s.formatAmount(_total),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.orange)),
            ]),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(labelText: s.t('notes')),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: s.t('save'),
            loading: _saving,
            onPressed: _saving || _items.isEmpty ? null : () async {
              setState(() => _saving = true);
              try {
                await widget.biz.createPurchase({
                  'purchase_date': DateTime.now().toIso8601String().substring(0, 10),
                  'payment_method': _paymentMode,
                  'notes': _notesCtrl.text.trim().isNotEmpty
                      ? _notesCtrl.text.trim()
                      : (_supplierCtrl.text.trim().isNotEmpty
                          ? 'Supplier: ${_supplierCtrl.text.trim()}'
                          : ''),
                  'items': _items,
                });
                if (mounted) {
                  Navigator.pop(context);
                  widget.onCreated();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.errorMessage(e))));
                }
              }
              if (mounted) setState(() => _saving = false);
            },
            icon: Icons.check_rounded,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Create Purchase Return Sheet ─────────────────────────────────────────────

class _CreateReturnSheet extends StatefulWidget {
  final AppSettings settings;
  final BusinessProvider biz;
  final List purchases;
  final VoidCallback onCreated;
  const _CreateReturnSheet({
    required this.settings, required this.biz,
    required this.purchases, required this.onCreated,
  });

  @override
  State<_CreateReturnSheet> createState() => _CreateReturnSheetState();
}

class _CreateReturnSheetState extends State<_CreateReturnSheet> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  Map? _selectedPurchase;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
              height: 4, width: 40, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)))),
          const Text('Record Purchase Return',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Return goods to supplier and credit the amount',
              style: TextStyle(fontSize: 13, color: AppColors.navy500)),
          const SizedBox(height: 20),

          // Select purchase
          DropdownButtonFormField<Map>(
            value: _selectedPurchase,
            hint: const Text('Select Purchase Bill'),
            decoration: const InputDecoration(
              labelText: 'Original Purchase',
              prefixIcon: Icon(Icons.local_shipping_rounded),
            ),
            items: widget.purchases.map((p) {
              final bill = p['bill_number'] as String? ?? 'Unknown';
              final sup  = p['supplier_name'] as String? ?? '';
              return DropdownMenuItem<Map>(
                value: p as Map,
                child: Text('$bill${sup.isNotEmpty ? " – $sup" : ""}',
                    overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedPurchase = v),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Return Amount',
              prefixIcon: const Icon(Icons.currency_rupee_rounded),
              hintText: _selectedPurchase != null
                  ? 'Max: ${s.formatAmount(double.tryParse(_selectedPurchase!['total']?.toString() ?? '0') ?? 0)}'
                  : '0.00',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason for Return',
              prefixIcon: Icon(Icons.notes_rounded),
              hintText: 'e.g. Defective goods, Wrong item...',
            ),
          ),
          const SizedBox(height: 20),

          PrimaryButton(
            label: 'Record Return',
            loading: _saving,
            icon: Icons.assignment_return_rounded,
            onPressed: _saving || _selectedPurchase == null || _amountCtrl.text.isEmpty
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await widget.biz.createPurchaseReturn({
                        'original_purchase': _selectedPurchase!['id'],
                        'amount': double.tryParse(_amountCtrl.text) ?? 0,
                        'reason': _reasonCtrl.text.trim(),
                      });
                      if (mounted) {
                        Navigator.pop(context);
                        widget.onCreated();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Purchase return recorded successfully'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ApiService.errorMessage(e))));
                      }
                    }
                    if (mounted) setState(() => _saving = false);
                  },
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
