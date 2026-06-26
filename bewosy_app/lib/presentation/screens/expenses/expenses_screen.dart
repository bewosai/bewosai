import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../providers/business_provider.dart';
import '../../widgets/app_widgets.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List _expenses = [];
  List<String> _categories = [];
  String _selectedCategory = 'ALL';
  bool _loading = true;
  double _totalAmount = 0;

  static const _catIcons = <String, IconData>{
    'RENT': Icons.home_rounded,
    'SALARY': Icons.people_rounded,
    'UTILITIES': Icons.bolt_rounded,
    'TRANSPORT': Icons.directions_car_rounded,
    'FOOD': Icons.restaurant_rounded,
    'MARKETING': Icons.campaign_rounded,
    'MAINTENANCE': Icons.build_rounded,
    'OTHER': Icons.more_horiz_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      _expenses = await context.read<BusinessProvider>().getExpenses();
      _totalAmount = _expenses.fold(
          0,
          (s, e) =>
              s + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0));
      final cats = <String>{'ALL'};
      for (final e in _expenses) {
        if (e['category'] != null) cats.add(e['category'].toString());
      }
      _categories = cats.toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List get _filtered => _selectedCategory == 'ALL'
      ? _expenses
      : _expenses
          .where((e) => e['category'] == _selectedCategory)
          .toList();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('expenses'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
                        Text(settings.t('total_expenses'),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
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
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (ctx, i) {
                      final cat = _categories[i];
                      final selected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                          selectedColor:
                              AppColors.orange.withOpacity(0.15),
                          checkmarkColor: AppColors.orange,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.orange
                                : AppColors.navy500,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.orange
                                : AppColors.lightBorder,
                          ),
                        ),
                      );
                    },
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
                              final cat =
                                  e['category']?.toString() ?? 'OTHER';
                              final icon = _catIcons[cat] ??
                                  Icons.more_horiz_rounded;
                              final amount = double.tryParse(
                                      e['amount']?.toString() ?? '0') ??
                                  0;
                              return AppCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(icon,
                                        color: AppColors.orange, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e['title'] ?? cat,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14),
                                        ),
                                        Row(children: [
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 3),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.navy50,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      20),
                                            ),
                                            child: Text(cat,
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
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'OTHER';
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
                    height: 4,
                    width: 40,
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
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(
                    labelText: settings.t('amount'),
                    prefixText: '${settings.currency} ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                      labelText: settings.t('category')),
                  items: _catIcons.keys
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(children: [
                            Icon(_catIcons[c]!, size: 16),
                            const SizedBox(width: 8),
                            Text(c),
                          ])))
                      .toList(),
                  onChanged: (v) => ss(() => category = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(labelText: settings.t('notes')),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: settings.t('save'),
                  loading: saving,
                  onPressed: saving
                      ? null
                      : () async {
                          ss(() => saving = true);
                          try {
                            await context.read<BusinessProvider>().createExpense({
                              'title': titleCtrl.text.trim(),
                              'amount': double.tryParse(
                                      amountCtrl.text.trim()) ??
                                  0,
                              'category': category,
                              'notes': notesCtrl.text.trim(),
                            });
                            if (context.mounted) {
                              Navigator.pop(ctx2);
                              _fetch();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            }
                          }
                          ss(() => saving = false);
                        },
                  icon: Icons.check_rounded,
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
