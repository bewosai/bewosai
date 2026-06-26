import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _SearchResult {
  final String type;
  final String title;
  final String subtitle;
  final String? amount;
  final IconData icon;
  final Color color;
  final Map<String, dynamic> data;

  const _SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.amount,
    required this.icon,
    required this.color,
    required this.data,
  });
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  List<_SearchResult> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    if (query == _lastQuery) return;
    _lastQuery = query;
    setState(() => _loading = true);

    final api = context.read<ApiService>();
    final settings = context.read<AppSettings>();
    final results = <_SearchResult>[];

    try {
      final r = await api.get('/parties/', params: {'search': query});
      for (final p in (r.data as List? ?? []).take(5)) {
        final m = Map<String, dynamic>.from(p as Map);
        results.add(_SearchResult(
          type: 'party',
          title: m['name']?.toString() ?? '',
          subtitle: m['party_type']?.toString() == 'CUSTOMER'
              ? 'Customer · ${m['phone'] ?? ''}'
              : 'Supplier · ${m['phone'] ?? ''}',
          icon: Icons.person_rounded,
          color: AppColors.info,
          data: m,
        ));
      }
    } catch (_) {}

    try {
      final r = await api.get('/sales/', params: {'search': query});
      for (final s in (r.data as List? ?? []).take(5)) {
        final m = Map<String, dynamic>.from(s as Map);
        final total = double.tryParse(m['total']?.toString() ?? '0') ?? 0;
        results.add(_SearchResult(
          type: 'sale',
          title: m['invoice_number']?.toString() ?? '',
          subtitle: '${m['party_name'] ?? 'Walk-in'} · ${m['sale_date'] ?? ''}',
          amount: settings.formatAmount(total),
          icon: Icons.receipt_long_rounded,
          color: AppColors.success,
          data: m,
        ));
      }
    } catch (_) {}

    try {
      final r = await api.get('/inventory/products/', params: {'search': query});
      for (final p in (r.data as List? ?? []).take(5)) {
        final m = Map<String, dynamic>.from(p as Map);
        final price = double.tryParse(m['selling_price']?.toString() ?? '0') ?? 0;
        final stock = m['current_stock']?.toString() ?? '0';
        results.add(_SearchResult(
          type: 'product',
          title: m['name']?.toString() ?? '',
          subtitle: 'Stock: $stock',
          amount: settings.formatAmount(price),
          icon: Icons.inventory_2_rounded,
          color: AppColors.warning,
          data: m,
        ));
      }
    } catch (_) {}

    try {
      final r = await api.get('/expenses/', params: {'search': query});
      for (final e in (r.data as List? ?? []).take(3)) {
        final m = Map<String, dynamic>.from(e as Map);
        final amount = double.tryParse(m['amount']?.toString() ?? '0') ?? 0;
        results.add(_SearchResult(
          type: 'expense',
          title: m['title']?.toString() ?? m['category']?.toString() ?? '',
          subtitle: '${m['category'] ?? ''} · ${m['date'] ?? ''}',
          amount: settings.formatAmount(amount),
          icon: Icons.receipt_rounded,
          color: AppColors.error,
          data: m,
        ));
      }
    } catch (_) {}

    try {
      final r = await api.get('/purchases/', params: {'search': query});
      for (final p in (r.data as List? ?? []).take(3)) {
        final m = Map<String, dynamic>.from(p as Map);
        final total = double.tryParse(m['total_amount']?.toString() ?? '0') ?? 0;
        results.add(_SearchResult(
          type: 'purchase',
          title: m['bill_number']?.toString() ?? '',
          subtitle: '${m['supplier_name'] ?? 'Supplier'} · ${m['purchase_date'] ?? ''}',
          amount: settings.formatAmount(total),
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF7C3AED),
          data: m,
        ));
      }
    } catch (_) {}

    if (mounted) setState(() {
      _results = results;
      _loading = false;
    });
  }

  void _onResultTap(_SearchResult result, AppSettings settings) {
    switch (result.type) {
      case 'party':
        Navigator.pop(context);
        context.go('/parties');
        break;
      case 'sale':
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _InvoicePreview(sale: result.data, settings: settings),
        ));
        break;
      case 'product':
        Navigator.pop(context);
        context.go('/inventory');
        break;
      case 'expense':
        Navigator.pop(context);
        context.go('/expenses');
        break;
      case 'purchase':
        Navigator.pop(context);
        context.go('/purchases');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          onChanged: _search,
          decoration: InputDecoration(
            hintText: 'Search customers, invoices, items...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {
                        _results = [];
                        _lastQuery = '';
                      });
                    },
                  )
                : null,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _ctrl.text.isEmpty
          ? _buildPlaceholder()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? _buildNoResults()
                  : _buildResults(settings),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded,
                size: 48, color: AppColors.orange),
          ),
          const SizedBox(height: 16),
          const Text(
            'Search Everything',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Customers · Invoices · Products\nExpenses · Purchases',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.navy500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 48, color: AppColors.navy500),
          const SizedBox(height: 12),
          Text(
            'No results for "${_ctrl.text}"',
            style: const TextStyle(color: AppColors.navy500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(AppSettings settings) {
    // Group by type
    final grouped = <String, List<_SearchResult>>{};
    for (final r in _results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    final typeLabels = {
      'party': 'Customers & Suppliers',
      'sale': 'Sales Invoices',
      'product': 'Products',
      'expense': 'Expenses',
      'purchase': 'Purchases',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${_results.length} result${_results.length != 1 ? 's' : ''} for "${_ctrl.text}"',
          style: const TextStyle(
              fontSize: 12, color: AppColors.navy500),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  typeLabels[entry.key] ?? entry.key,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy500,
                      letterSpacing: 0.5),
                ),
              ),
              ...entry.value.map((result) => _ResultTile(
                    result: result,
                    onTap: () => _onResultTap(result, settings),
                  )),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        tileColor: Theme.of(context).colorScheme.surface,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: result.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(result.icon, color: result.color, size: 20),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          result.subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.navy500),
        ),
        trailing: result.amount != null
            ? Text(
                result.amount!,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: result.color,
                    fontSize: 13),
              )
            : const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.navy500),
        onTap: onTap,
      ),
    );
  }
}

// Inline invoice preview for search results
class _InvoicePreview extends StatelessWidget {
  final Map<String, dynamic> sale;
  final AppSettings settings;

  const _InvoicePreview({required this.sale, required this.settings});

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(sale['paid_amount']?.toString() ?? '0') ?? 0;
    final balance = total - paid;
    final items = List<Map<String, dynamic>>.from(
        (sale['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));

    return Scaffold(
      appBar: AppBar(
        title: Text(sale['invoice_number']?.toString() ?? 'Invoice'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(sale['invoice_number']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(sale['status']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ),
                    ]),
                const Divider(height: 16),
                ...items.map((item) {
                  final qty = double.tryParse(
                          item['quantity']?.toString() ?? '1') ??
                      1;
                  final price = double.tryParse(
                          item['unit_price']?.toString() ?? '0') ??
                      0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(
                              item['product_name']?.toString() ?? '',
                              style: const TextStyle(fontSize: 13))),
                      Text('×${qty.toStringAsFixed(0)}  ',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.navy500)),
                      Text(settings.formatAmount(qty * price),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ]),
                  );
                }).toList(),
                const Divider(height: 16),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance Due',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        settings.formatAmount(balance.abs()),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: balance > 0
                                ? AppColors.error
                                : AppColors.success),
                      ),
                    ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
