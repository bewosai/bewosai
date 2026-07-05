import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_widgets.dart';

class BankingScreen extends StatefulWidget {
  const BankingScreen({super.key});

  @override
  State<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends State<BankingScreen> {
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  static const _accountTypeIcons = {
    'CASH': Icons.payments_rounded,
    'BANK': Icons.account_balance_rounded,
    'ESEWA': Icons.phone_android_rounded,
    'KHALTI': Icons.phone_android_rounded,
    'IME_PAY': Icons.mobile_friendly_rounded,
    'MOBILE_BANKING': Icons.smartphone_rounded,
    'OTHER': Icons.wallet_rounded,
  };

  static const _accountTypeColors = {
    'CASH': AppColors.success,
    'BANK': AppColors.info,
    'ESEWA': Color(0xFF3EA96B),
    'KHALTI': Color(0xFF5C2D91),
    'IME_PAY': Color(0xFFD32F2F),
    'MOBILE_BANKING': AppColors.warning,
    'OTHER': AppColors.navy500,
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final r1 = await api.get('/banking/accounts/');
      _accounts = List<Map<String, dynamic>>.from(
          (r1.data as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
      try {
        final r2 = await api.get('/banking/transactions/', params: {'limit': '20'});
        _transactions = List<Map<String, dynamic>>.from(
            (r2.data as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double get _totalBalance => _accounts.fold(
      0,
      (s, a) =>
          s + (double.tryParse(a['balance']?.toString() ?? '0') ?? 0));

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Accounts',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'banking_fab',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showAddAccount(context, settings),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total balance card
                    _buildTotalCard(settings),
                    const SizedBox(height: 20),

                    // Accounts grid
                    const Text('Accounts',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 12),
                    _accounts.isEmpty
                        ? EmptyState(
                            icon: Icons.account_balance_wallet_rounded,
                            message: 'No payment accounts yet.\nTap + to add one.',
                            action: TextButton.icon(
                              onPressed: () =>
                                  _showAddAccount(context, settings),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Account'),
                            ),
                          )
                        : _buildAccountsGrid(settings),

                    // Recent transactions
                    if (_transactions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Recent Transactions',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 12),
                      ..._transactions.take(10).map(
                            (t) => _TransactionTile(
                              transaction: t,
                              settings: settings,
                            ),
                          ),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTotalCard(AppSettings settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy900, AppColors.navy700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_wallet_rounded,
            color: AppColors.orange, size: 36),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Balance',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              settings.formatAmount(_totalBalance),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_accounts.length} acct${_accounts.length != 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  Widget _buildAccountsGrid(AppSettings settings) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: _accounts.length,
      itemBuilder: (ctx, i) {
        final acc = _accounts[i];
        final type = acc['account_type']?.toString() ?? 'OTHER';
        final color = _accountTypeColors[type] ?? AppColors.navy500;
        final icon = _accountTypeIcons[type] ?? Icons.wallet_rounded;
        final balance =
            double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;

        return GestureDetector(
          onTap: () => _showAccountDetail(acc, settings),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showEditAccount(acc, settings),
                    child: const Icon(Icons.more_vert_rounded,
                        size: 16, color: AppColors.navy500),
                  ),
                ]),
                const Spacer(),
                Text(
                  acc['account_name']?.toString() ?? 'Account',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  settings.formatAmount(balance),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: balance >= 0 ? color : AppColors.error),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAccountDetail(
      Map<String, dynamic> acc, AppSettings settings) {
    final opening =
        double.tryParse(acc['opening_balance']?.toString() ?? '0') ?? 0;
    final current =
        double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(acc['account_name']?.toString() ?? '',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(acc['account_type']?.toString() ?? '',
                style: const TextStyle(
                    color: AppColors.navy500, fontSize: 13)),
            const SizedBox(height: 20),
            _DetailRow('Opening Balance',
                settings.formatAmount(opening)),
            _DetailRow(
                'Current Balance', settings.formatAmount(current)),
            if ((acc['notes'] ?? '').toString().isNotEmpty)
              _DetailRow('Notes', acc['notes']?.toString() ?? ''),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddAccount(BuildContext context, AppSettings settings) {
    _showAccountForm(context, settings, null);
  }

  void _showEditAccount(
      Map<String, dynamic> acc, AppSettings settings) {
    _showAccountForm(context, settings, acc);
  }

  void _showAccountForm(BuildContext context, AppSettings settings,
      Map<String, dynamic>? existing) {
    final nameCtrl = TextEditingController(
        text: existing?['account_name']?.toString() ?? '');
    final openingCtrl = TextEditingController(
        text: existing?['opening_balance']?.toString() ?? '0');
    final notesCtrl = TextEditingController(
        text: existing?['notes']?.toString() ?? '');
    String accType =
        existing?['account_type']?.toString() ?? 'CASH';
    bool saving = false;

    const types = [
      {'key': 'CASH', 'label': 'Cash'},
      {'key': 'BANK', 'label': 'Bank'},
      {'key': 'ESEWA', 'label': 'eSewa'},
      {'key': 'KHALTI', 'label': 'Khalti'},
      {'key': 'IME_PAY', 'label': 'IME Pay'},
      {'key': 'MOBILE_BANKING', 'label': 'Mobile Banking'},
      {'key': 'OTHER', 'label': 'Other'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom),
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
                Text(
                  existing != null ? 'Edit Account' : 'Add Payment Account',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Name',
                    hintText: 'e.g. Shop Cash, eSewa 98XXXXX',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: accType,
                  decoration:
                      const InputDecoration(labelText: 'Account Type'),
                  items: types
                      .map((t) => DropdownMenuItem(
                            value: t['key'],
                            child: Text(t['label']!),
                          ))
                      .toList(),
                  onChanged: (v) => ss(() => accType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openingCtrl,
                  decoration: InputDecoration(
                    labelText: 'Opening Balance',
                    prefixText: '${settings.currency} ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: saving ? 'Saving...' : 'Save Account',
                  loading: saving,
                  icon: Icons.check_rounded,
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          ss(() => saving = true);
                          try {
                            final api = context.read<ApiService>();
                            final payload = {
                              'account_name': nameCtrl.text.trim(),
                              'account_type': accType,
                              'opening_balance':
                                  double.tryParse(openingCtrl.text) ?? 0,
                              'notes': notesCtrl.text.trim(),
                            };
                            if (existing != null) {
                              await api.patch(
                                  '/banking/accounts/${existing['id']}/',
                                  data: payload);
                            } else {
                              await api.post('/banking/accounts/',
                                  data: payload);
                            }
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.navy500)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final AppSettings settings;

  const _TransactionTile(
      {required this.transaction, required this.settings});

  @override
  Widget build(BuildContext context) {
    final type = transaction['transaction_type']?.toString() ?? '';
    final amount =
        double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0;
    final isIn = type == 'IN' || type == 'CREDIT';
    final date = transaction['date']?.toString() ?? '';
    final ref = transaction['reference']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isIn
                ? AppColors.successLight
                : AppColors.errorLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isIn
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: isIn ? AppColors.success : AppColors.error,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction['description']?.toString() ?? ref,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(date,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.navy500)),
            ],
          ),
        ),
        Text(
          '${isIn ? '+' : '-'}${settings.formatAmount(amount)}',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isIn ? AppColors.success : AppColors.error,
              fontSize: 14),
        ),
      ]),
    );
  }
}
