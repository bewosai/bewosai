import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/receipt_image_picker.dart';
import '../../data/models/expense_model.dart';
import '../providers/expense_provider.dart';

class ExpensesScreen extends StatefulWidget {
  final bool openAddOnStart;

  const ExpensesScreen({super.key, this.openAddOnStart = false});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  int? _categoryFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ExpenseProvider>().load();
      if (widget.openAddOnStart && mounted) _openAddSheet();
    });
  }

  void _openAddSheet({Expense? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExpenseFormSheet(expense: expense),
    );
  }

  List<Expense> _filtered(List<Expense> expenses) {
    var list = expenses;
    if (_categoryFilter != null) {
      list = list.where((e) => e.category == _categoryFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (e) =>
                e.description.toLowerCase().contains(q) ||
                e.categoryName.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<ExpenseProvider>();
    final filtered = _filtered(ep.expenses);
    final width = MediaQuery.sizeOf(context).width;
    final padding = width >= 600 ? 20.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: const [HomeLogoButton()],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expenses_fab',
        onPressed: () => _openAddSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: () => context.read<ExpenseProvider>().load(),
          child: ep.isLoading && ep.expenses.isEmpty
              ? const LoadingView()
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(padding),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = constraints.maxWidth >= 500 ? 2 : 2;
                        const spacing = 12.0;
                        final cellW =
                            (constraints.maxWidth - spacing * (cols - 1)) /
                            cols;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: cellW,
                              child: KpiCard.currency(
                                label: 'This Month',
                                value: ep.thisMonthTotal,
                                icon: Icons.calendar_month_outlined,
                                color: AppColors.orange,
                              ),
                            ),
                            SizedBox(
                              width: cellW,
                              child: KpiCard.currency(
                                label: 'All Time',
                                value: ep.allTimeTotal,
                                icon: Icons.account_balance_wallet_outlined,
                                color: AppColors.navy600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SearchField(
                      hint: 'Search description or category',
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppFilterChip(
                              label: 'All',
                              selected: _categoryFilter == null,
                              onTap: () =>
                                  setState(() => _categoryFilter = null),
                            ),
                          ),
                          ...ep.categories.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppFilterChip(
                                label: c.name,
                                selected: _categoryFilter == c.id,
                                onTap: () =>
                                    setState(() => _categoryFilter = c.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_outlined,
                        title: 'No expenses found',
                      )
                    else
                      ...filtered.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            onTap: () => _openAddSheet(expense: e),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.errorBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_outlined,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.description.isNotEmpty
                                            ? e.description
                                            : e.categoryName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${e.categoryName} · ${Formatters.dateShort(e.date)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (e.createdAt != null)
                                        Text(
                                          'Added ${Formatters.dateShort(e.createdAt)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Formatters.currency(e.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.navy300,
                                  ),
                                  onPressed: () async {
                                    final provider = context
                                        .read<ExpenseProvider>();
                                    final confirmed =
                                        await showDeleteConfirmDialog(context);
                                    if (!confirmed || !mounted) return;
                                    final ok = await provider.delete(e.id);
                                    if (!context.mounted) return;
                                    if (!ok) {
                                      showAppSnackBar(
                                        context,
                                        provider.error ?? 'Delete failed',
                                        isError: true,
                                      );
                                    }
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

class _ExpenseFormSheet extends StatefulWidget {
  final Expense? expense;

  const _ExpenseFormSheet({this.expense});

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  late String _paymentMethod;
  int? _category;
  bool _saving = false;
  bool _categoryInitialized = false;
  File? _receiptImageFile;
  String? _receiptImageUrl;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amountController = TextEditingController(
      text: e != null ? e.amount.toString() : '',
    );
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _date = e?.date ?? DateTime.now();
    _paymentMethod = e?.paymentMethod ?? 'CASH';
    _category = e?.category;
    _receiptImageUrl = e?.receiptImageUrl;
  }

  Future<void> _pickReceiptImage() async {
    final path = await pickReceiptImagePath(context);
    if (path == null || !mounted) return;
    setState(() {
      _receiptImageFile = File(path);
      _receiptImageUrl = null;
    });
  }

  void _removeReceiptImage() {
    setState(() {
      _receiptImageFile = null;
      _receiptImageUrl = null;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final expense = Expense(
      id: widget.expense?.id ?? 0,
      category: _category,
      categoryName: '',
      amount: double.tryParse(_amountController.text.trim()) ?? 0,
      date: _date,
      description: _descriptionController.text.trim(),
      paymentMethod: _paymentMethod,
    );

    final ok = await context.read<ExpenseProvider>().save(
      expense,
      id: widget.expense?.id,
      receiptImage: _receiptImageFile,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
    } else {
      final err = context.read<ExpenseProvider>().error;
      showAppSnackBar(context, err ?? 'Failed to save expense', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ExpenseProvider>().categories;

    // Set default category once when list arrives (edit keeps existing).
    if (!_categoryInitialized &&
        _category == null &&
        categories.isNotEmpty &&
        widget.expense == null) {
      _category = categories.first.id;
      _categoryInitialized = true;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: widget.expense == null ? 'Add Expense' : 'Edit Expense'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount *'),
                validator: (v) => Validators.positiveNumber(v, 'Amount'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await AppDatePicker.pick(
                    context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(Formatters.date(_date)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue:
                    _category != null &&
                        categories.any((c) => c.id == _category)
                    ? _category
                    : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: AppConstants.paymentMethods.contains(_paymentMethod)
                    ? _paymentMethod
                    : 'CASH',
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: AppConstants.paymentMethods
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(AppConstants.paymentMethodLabels[m] ?? m),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _paymentMethod = v ?? 'CASH'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text('Receipt Photo (optional)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ReceiptImagePicker(
                imageFile: _receiptImageFile,
                imageUrl: _receiptImageUrl,
                onTap: _pickReceiptImage,
                onRemove: _removeReceiptImage,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Save Expense',
                isLoading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
