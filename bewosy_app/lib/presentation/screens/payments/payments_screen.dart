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
  bool _loading = true;

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
    final api = context.read<ApiService>();
    try {
      final r1 = await api.get('/sales/', params: {'has_balance': true});
      final r2 = await api.get('/purchases/', params: {'has_balance': true});
      _receivable = (r1.data as List?) ?? [];
      _payable = (r2.data as List?) ?? [];
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
            ((double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0) -
                (double.tryParse(r['paid_amount']?.toString() ?? '0') ?? 0)));

    final totalPayable = _payable.fold<double>(
        0,
        (s, r) =>
            s +
            ((double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0) -
                (double.tryParse(r['paid_amount']?.toString() ?? '0') ?? 0)));

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('payments'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
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
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text('${settings.t('receivable')} (${_receivable.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text('${settings.t('payable')} (${_payable.length})'),
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
                    ],
                  ),
                ),
              ],
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
          final total =
              double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
          final paid =
              double.tryParse(item['paid_amount']?.toString() ?? '0') ?? 0;
          final balance = total - paid;
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
                    Text(item['bill_number'] ?? '—',
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
