import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/models/banking_model.dart';
import '../providers/banking_provider.dart';

class BankingScreen extends StatefulWidget {
  const BankingScreen({super.key});

  @override
  State<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends State<BankingScreen> {
  String _txSearch = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BankingProvider>().load());
  }

  List<BankTransaction> _filteredTransactions(List<BankTransaction> transactions) {
    if (_txSearch.isEmpty) return transactions;
    final q = _txSearch.toLowerCase();
    return transactions
        .where((t) => t.description.toLowerCase().contains(q) || t.reference.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BankingProvider>();
    final filteredTransactions = _filteredTransactions(bp.transactions);

    return Scaffold(
      appBar: AppBar(title: const Text('Banking'), actions: const [HomeLogoButton()]),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'banking_fab',
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const BankAccountFormSheet()),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: bp.isLoading && bp.accounts.isEmpty
          ? const LoadingView()
          : ResponsiveBody(child: RefreshIndicator(
              onRefresh: () => context.read<BankingProvider>().load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.navy900, AppColors.navy700]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Balance', style: TextStyle(color: AppColors.navy200, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(Formatters.currency(bp.totalBalance), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${bp.accounts.length} accounts', style: const TextStyle(color: AppColors.navy300, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (bp.accounts.isEmpty)
                    const EmptyState(icon: Icons.account_balance_outlined, title: 'No accounts yet', message: 'Add a cash, bank, eSewa or Khalti account.')
                  else
                    ...bp.accounts.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            color: bp.selectedAccountId == a.id ? AppColors.orangeLight : AppColors.surface,
                            onTap: () => context.read<BankingProvider>().selectAccount(a.id),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.accountName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('${AppConstants.bankAccountTypeLabels[a.accountType] ?? a.accountType}${a.bankName.isNotEmpty ? ' · ${a.bankName}' : ''}',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text(Formatters.currency(a.balance), style: const TextStyle(fontWeight: FontWeight.w800)),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => BankAccountFormSheet(account: a)),
                                ),
                              ],
                            ),
                          ),
                        )),
                  if (bp.selectedAccountId != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SectionHeader(title: 'Transactions'),
                        TextButton.icon(
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _TransactionFormSheet(accountId: bp.selectedAccountId!),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SearchField(
                      hint: 'Search description, reference',
                      onChanged: (v) => setState(() => _txSearch = v),
                    ),
                    const SizedBox(height: 10),
                    if (filteredTransactions.isEmpty)
                      AppSectionCard(children: [Text(bp.transactions.isEmpty ? 'No transactions yet' : 'No matching transactions', style: TextStyle(color: AppColors.textSecondary))])
                    else
                      AppSectionCard(
                        children: filteredTransactions.map((t) {
                          final isLast = t == filteredTransactions.last;
                          return Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                            child: Row(
                              children: [
                                Icon(t.transactionType == 'CREDIT' ? Icons.arrow_downward : Icons.arrow_upward,
                                    size: 16, color: t.transactionType == 'CREDIT' ? AppColors.success : AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.description.isNotEmpty ? t.description : t.reference, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(Formatters.dateShort(t.date), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${t.transactionType == 'CREDIT' ? '+' : '-'}${Formatters.currency(t.amount)}',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: t.transactionType == 'CREDIT' ? AppColors.success : AppColors.error),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            )),
    );
  }
}

class BankAccountFormSheet extends StatefulWidget {
  final BankAccount? account;
  const BankAccountFormSheet({super.key, this.account});

  @override
  State<BankAccountFormSheet> createState() => _BankAccountFormSheetState();
}

class _BankAccountFormSheetState extends State<BankAccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.account?.accountName ?? '');
  late final _bankController = TextEditingController(text: widget.account?.bankName ?? '');
  late final _numberController = TextEditingController(text: widget.account?.accountNumber ?? '');
  late final _openingController = TextEditingController(text: widget.account?.openingBalance.toString() ?? '0');
  late String _type = widget.account?.accountType ?? 'CASH';
  bool _saving = false;

  // Mirrors the backend's own validate_account_type: counts active
  // accounts of [type] other than the one being edited, so the limit
  // agrees exactly with what the server would reject.
  int _countOfType(String type) => context
      .read<BankingProvider>()
      .accounts
      .where((a) => a.accountType == type && a.isActive && a.id != widget.account?.id)
      .length;

  bool _isTypeFull(String type) {
    final limit = AppConstants.bankAccountTypeLimits[type];
    return limit != null && _countOfType(type) >= limit;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isTypeFull(_type)) {
      showAppSnackBar(
        context,
        'You can only have ${AppConstants.bankAccountTypeLimits[_type]} ${AppConstants.bankAccountTypeLabels[_type]} account(s). Remove or deactivate one first.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    final account = BankAccount(
      id: widget.account?.id ?? 0,
      accountName: _nameController.text.trim(),
      bankName: _bankController.text.trim(),
      accountNumber: _numberController.text.trim(),
      accountType: _type,
      openingBalance: double.tryParse(_openingController.text) ?? 0,
      balance: 0,
      isActive: true,
    );
    final provider = context.read<BankingProvider>();
    final ok = await provider.saveAccount(account, id: widget.account?.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      showAppSnackBar(context, provider.error ?? 'Failed to save account', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: widget.account == null ? 'Add Account' : 'Edit Account'),
              const SizedBox(height: 16),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Account Name *'), validator: (v) => Validators.required(v, 'Account name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: AppConstants.bankAccountTypes.map((t) {
                  final full = _isTypeFull(t);
                  final label = AppConstants.bankAccountTypeLabels[t] ?? t;
                  return DropdownMenuItem(
                    value: t,
                    enabled: !full,
                    child: Text(full ? '$label (limit reached)' : label),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _type = v ?? 'CASH'),
              ),
              if (_isTypeFull(_type))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "You've reached the limit for this account type — remove or deactivate one first, or pick another type.",
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(controller: _bankController, decoration: const InputDecoration(labelText: 'Bank Name (optional)')),
              const SizedBox(height: 12),
              TextFormField(controller: _numberController, decoration: const InputDecoration(labelText: 'Account Number (optional)')),
              const SizedBox(height: 12),
              TextFormField(controller: _openingController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening Balance')),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Save Account',
                isLoading: _saving,
                onPressed: _isTypeFull(_type) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionFormSheet extends StatefulWidget {
  final int accountId;
  const _TransactionFormSheet({required this.accountId});

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _refController = TextEditingController();
  String _type = 'CREDIT';
  DateTime _date = DateTime.now();
  bool _saving = false;

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      showAppSnackBar(context, 'Enter a valid amount', isError: true);
      return;
    }
    setState(() => _saving = true);
    final transaction = BankTransaction(
      id: 0,
      account: widget.accountId,
      accountName: '',
      transactionType: _type,
      amount: amount,
      date: _date,
      description: _descController.text.trim(),
      reference: _refController.text.trim(),
    );
    final ok = await context.read<BankingProvider>().addTransaction(transaction);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Add Transaction'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _type = 'CREDIT'),
                style: OutlinedButton.styleFrom(backgroundColor: _type == 'CREDIT' ? AppColors.successBg : null, side: BorderSide(color: _type == 'CREDIT' ? AppColors.success : AppColors.navy200)),
                child: const Text('Money In'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _type = 'DEBIT'),
                style: OutlinedButton.styleFrom(backgroundColor: _type == 'DEBIT' ? AppColors.errorBg : null, side: BorderSide(color: _type == 'DEBIT' ? AppColors.error : AppColors.navy200)),
                child: const Text('Money Out'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount *')),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await AppDatePicker.pick(context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Date'), child: Text(Formatters.date(_date))),
          ),
          const SizedBox(height: 12),
          TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          TextField(controller: _refController, decoration: const InputDecoration(labelText: 'Reference / Cheque No.')),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Save Transaction', isLoading: _saving, onPressed: _submit),
        ],
      ),
    );
  }
}
