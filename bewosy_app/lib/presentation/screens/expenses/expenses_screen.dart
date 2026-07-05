import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../providers/business_provider.dart';
import '../../widgets/app_widgets.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'ALL';
  bool _loading = true;
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        context.read<BusinessProvider>().getExpenses(),
        api.get('/expenses/categories/'),
      ]);
      _expenses = results[0] as List;
      _categories = List<Map<String, dynamic>>.from(
          ((results[1] as dynamic).data as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
      _totalAmount = _expenses.fold(
          0, (s, e) => s + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List get _filtered {
    if (_selectedCategory == 'ALL') return _expenses;
    return _expenses
        .where((e) => e['category']?.toString() == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('expenses'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expenses_fab',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showAddSheet(context, settings),
        icon: const Icon(Icons.add_rounded),
        label: Text(settings.t('new_expense')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A2540), Color(0xFF1a3a60)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: AppColors.orange, size: 32),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Expenses',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 12)),
                        Text(settings.formatAmount(_totalAmount),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ]),
                ),
                // Category filter chips
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: _selectedCategory == 'ALL',
                            onSelected: (_) =>
                                setState(() => _selectedCategory = 'ALL'),
                            selectedColor: AppColors.orange.withOpacity(0.15),
                            checkmarkColor: AppColors.orange,
                            labelStyle: TextStyle(
                              color: _selectedCategory == 'ALL'
                                  ? AppColors.orange
                                  : AppColors.navy500,
                              fontWeight: _selectedCategory == 'ALL'
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: _selectedCategory == 'ALL'
                                  ? AppColors.orange
                                  : AppColors.lightBorder,
                            ),
                          ),
                        ),
                        ..._categories.map((cat) {
                          final id = cat['id']?.toString() ?? '';
                          final name = cat['name']?.toString() ?? '';
                          final sel = _selectedCategory == id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(name),
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = id),
                              selectedColor: AppColors.orange.withOpacity(0.15),
                              checkmarkColor: AppColors.orange,
                              labelStyle: TextStyle(
                                color: sel ? AppColors.orange : AppColors.navy500,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                                fontSize: 12,
                              ),
                              side: BorderSide(
                                color: sel ? AppColors.orange : AppColors.lightBorder,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_rounded,
                          message: settings.t('no_data'),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _fetch(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final e = _filtered[i];
                              final catName =
                                  e['category_name']?.toString() ?? '';
                              final desc =
                                  e['description']?.toString() ?? '';
                              final amount =
                                  double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
                              return AppCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        color: AppColors.orange,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          catName.isNotEmpty ? catName : 'Expense',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14),
                                        ),
                                        if (desc.isNotEmpty)
                                          Text(desc,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.navy500),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        Row(children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 3),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.navy50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              e['payment_method']?.toString() ?? 'CASH',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.navy500)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(e['date'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.navy500)),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    settings.formatAmount(amount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.error,
                                        fontSize: 15),
                                  ),
                                ]),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  void _showAddSheet(BuildContext context, AppSettings settings) {
    final descCtrl   = TextEditingController();
    final amountCtrl = TextEditingController();
    int? selectedCategoryId;
    String paymentMethod = 'CASH';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx2).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4, width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(settings.t('new_expense'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.notes_rounded)),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(
                    labelText: settings.t('amount'),
                    prefixText: '${settings.currency} ',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                if (_categories.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    hint: const Text('Select Category (optional)'),
                    decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined)),
                    items: _categories.map((cat) {
                      final id = cat['id'] as int? ?? 0;
                      final name = cat['name'] as String? ?? '';
                      return DropdownMenuItem<int>(
                          value: id, child: Text(name));
                    }).toList(),
                    onChanged: (v) => ss(() => selectedCategoryId = v),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(Icons.payments_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'CASH',   child: Text('Cash')),
                    DropdownMenuItem(value: 'BANK',   child: Text('Bank')),
                    DropdownMenuItem(value: 'ESEWA',  child: Text('eSewa')),
                    DropdownMenuItem(value: 'KHALTI', child: Text('Khalti')),
                  ],
                  onChanged: (v) => ss(() => paymentMethod = v!),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: settings.t('save'),
                  loading: saving,
                  icon: Icons.check_rounded,
                  onPressed: saving
                      ? null
                      : () async {
                          if (amountCtrl.text.trim().isEmpty) return;
                          ss(() => saving = true);
                          try {
                            final data = <String, dynamic>{
                              'amount': double.tryParse(amountCtrl.text.trim()) ?? 0,
                              'date': DateTime.now().toIso8601String().substring(0, 10),
                              'description': descCtrl.text.trim(),
                              'payment_method': paymentMethod,
                            };
                            if (selectedCategoryId != null) {
                              data['category'] = selectedCategoryId;
                            }
                            await context.read<BusinessProvider>().createExpense(data);
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
