import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_widgets.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _receivable = [];
  List _payable = [];
  List _recentPayments = [];
  bool _loading = true;

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
    final api = context.read<ApiService>();
    try {
      final r1 = await api
          .get('/sales/', params: {'has_balance': true})
          .then((r) => r)
          .onError((_, __) => throw '');
      _receivable = (r1.data as List?) ?? [];
    } catch (_) {}
    try {
      final r2 = await api.get('/purchases/', params: {'has_balance': true});
      _payable = (r2.data as List?) ?? [];
    } catch (_) {}
    try {
      final r3 = await api.get('/parties/payments/');
      _recentPayments = (r3.data as List?) ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    final totalReceivable = _receivable.fold<double>(
        0,
        (s, r) =>
            s +
            ((double.tryParse(r['due_amount']?.toString() ?? r['total']?.toString() ?? '0') ?? 0)));

    final totalPayable = _payable.fold<double>(
        0,
        (s, r) =>
            s +
            ((double.tryParse(r['due_amount']?.toString() ?? r['total']?.toString() ?? '0') ?? 0)));

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('payments'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'payments_fab',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showRecordPaymentSheet(context, settings),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record Payment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: _SummaryCard(
                        label: settings.t('receivable'),
                        amount: totalReceivable,
                        color: AppColors.success,
                        bgColor: AppColors.successLight,
                        icon: Icons.arrow_downward_rounded,
                        settings: settings,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: settings.t('payable'),
                        amount: totalPayable,
                        color: AppColors.error,
                        bgColor: AppColors.errorLight,
                        icon: Icons.arrow_upward_rounded,
                        settings: settings,
                      ),
                    ),
                  ]),
                ),
                TabBar(
                  controller: _tabs,
                  labelColor: AppColors.orange,
                  unselectedLabelColor: AppColors.navy500,
                  indicatorColor: AppColors.orange,
                  isScrollable: true,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text('Receivable (${_receivable.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text('Payable (${_payable.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text('History (${_recentPayments.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _DueBillList(
                        items: _receivable,
                        settings: settings,
                        type: 'receivable',
                        onRefresh: _fetch,
                      ),
                      _DueBillList(
                        items: _payable,
                        settings: settings,
                        type: 'payable',
                        onRefresh: _fetch,
                      ),
                      _PaymentHistoryList(
                        items: _recentPayments,
                        settings: settings,
                        onRefresh: _fetch,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showRecordPaymentSheet(BuildContext context, AppSettings settings) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String direction = 'IN';
    String paymentMethod = 'CASH';
    Map<String, dynamic>? selectedParty;
    List<Map<String, dynamic>> parties = [];
    bool saving = false;
    bool loadingParties = true;

    const methods = [
      {'key': 'CASH',   'label': 'Cash'},
      {'key': 'BANK',   'label': 'Bank'},
      {'key': 'ESEWA',  'label': 'eSewa'},
      {'key': 'KHALTI', 'label': 'Khalti'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, ss) {
          // Load parties once
          if (loadingParties) {
            loadingParties = false;
            context.read<ApiService>().get('/parties/').then((res) {
              if (ctx2.mounted) {
                ss(() => parties = List<Map<String, dynamic>>.from(
                    (res.data as List? ?? [])
                        .map((e) => Map<String, dynamic>.from(e as Map))));
              }
            }).catchError((_) {});
          }

          return Padding(
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
                  const Text('Record Payment',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  // Direction toggle
                  Row(children: [
                    for (final d in [
                      ('IN', 'Payment In', Icons.arrow_downward_rounded, AppColors.success),
                      ('OUT', 'Payment Out', Icons.arrow_upward_rounded, AppColors.error),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ss(() => direction = d.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: EdgeInsets.only(
                                right: d.$1 == 'IN' ? 8 : 0),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            decoration: BoxDecoration(
                              color: direction == d.$1
                                  ? d.$4
                                  : Colors.transparent,
                              border: Border.all(
                                color: direction == d.$1
                                    ? d.$4
                                    : AppColors.lightBorder,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(d.$3,
                                    size: 16,
                                    color: direction == d.$1
                                        ? Colors.white
                                        : d.$4),
                                const SizedBox(width: 6),
                                Text(d.$2,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: direction == d.$1
                                          ? Colors.white
                                          : d.$4,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  // Party selector
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedParty,
                    decoration: InputDecoration(
                      labelText: direction == 'IN'
                          ? 'From Customer'
                          : 'To Supplier',
                      prefixIcon:
                          const Icon(Icons.person_rounded),
                    ),
                    items: parties.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p['name']?.toString() ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) => ss(() => selectedParty = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${settings.currency} ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration:
                        const InputDecoration(labelText: 'Payment Method'),
                    items: methods
                        .map((m) => DropdownMenuItem(
                              value: m['key'],
                              child: Text(m['label']!),
                            ))
                        .toList(),
                    onChanged: (v) => ss(() => paymentMethod = v!),
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
                    label: saving ? 'Saving...' : 'Record Payment',
                    loading: saving,
                    icon: Icons.check_rounded,
                    onPressed: saving
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountCtrl.text.trim());
                            if (amount == null || amount <= 0) return;
                            ss(() => saving = true);
                            try {
                              await context.read<ApiService>().post(
                                '/parties/payments/',
                                data: {
                                  'party': selectedParty?['id'],
                                  'amount': amount,
                                  'payment_method': paymentMethod,
                                  'payment_type': direction,
                                  'date': DateTime.now().toIso8601String().substring(0, 10),
                                  'note': notesCtrl.text.trim(),
                                },
                              );
                              if (context.mounted) {
                                Navigator.pop(ctx2);
                                _fetch();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment recorded!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
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
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final AppSettings settings;
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.navy500)),
              Text(settings.formatAmount(amount),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _DueBillList extends StatelessWidget {
  final List items;
  final AppSettings settings;
  final String type;
  final VoidCallback onRefresh;
  const _DueBillList({
    required this.items,
    required this.settings,
    required this.type,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_rounded,
        message: type == 'receivable'
            ? 'No pending receivables'
            : 'No pending payables',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          final balance =
              double.tryParse(item['due_amount']?.toString() ?? '0') ??
              ((double.tryParse(item['total']?.toString() ?? '0') ?? 0) -
               (double.tryParse(item['paid_amount']?.toString() ?? '0') ?? 0));
          final isOverdue = item['is_overdue'] == true;

          return AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? AppColors.errorLight
                      : AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  type == 'receivable'
                      ? Icons.receipt_long_rounded
                      : Icons.local_shipping_rounded,
                  color:
                      isOverdue ? AppColors.error : AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        type == 'receivable'
                            ? (item['invoice_number'] ?? '—')
                            : (item['bill_number'] ?? '—'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                        type == 'receivable'
                            ? (item['party_name'] ?? settings.t('customer'))
                            : (item['supplier_name'] ??
                                settings.t('supplier')),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.navy500)),
                    if (item['due_date'] != null)
                      Row(children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_rounded
                              : Icons.calendar_today_rounded,
                          size: 12,
                          color: isOverdue
                              ? AppColors.error
                              : AppColors.navy500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${item['due_date']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue
                                ? AppColors.error
                                : AppColors.navy500,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    settings.formatAmount(balance),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: type == 'receivable'
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  if (isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('OVERDUE',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error)),
                    ),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _PaymentHistoryList extends StatelessWidget {
  final List items;
  final AppSettings settings;
  final VoidCallback onRefresh;

  const _PaymentHistoryList({
    required this.items,
    required this.settings,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        message: 'No payment history yet.\nTap + to record a payment.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          final amount =
              double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
          final isIn = (item['payment_type']?.toString() ?? 'IN') == 'IN';
          final method = item['payment_method']?.toString() ?? '';
          final partyName = item['party_name']?.toString() ??
              item['party']?.toString() ?? '';
          final date = item['created_at']?.toString() ??
              item['date']?.toString() ?? '';

          return AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isIn ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIn
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isIn ? AppColors.success : AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIn ? 'Payment In' : 'Payment Out',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (partyName.isNotEmpty)
                      Text(partyName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.navy500)),
                    Row(children: [
                      if (method.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.navy50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(method,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.navy500)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (date.isNotEmpty)
                        Text(
                          date.length > 10 ? date.substring(0, 10) : date,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.navy500),
                        ),
                    ]),
                  ],
                ),
              ),
              Text(
                '${isIn ? '+' : '-'}${settings.formatAmount(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isIn ? AppColors.success : AppColors.error,
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
