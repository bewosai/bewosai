import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/i18n/translations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/payment_status.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/models/sale_model.dart';
import '../providers/sale_provider.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _filter = 'ALL';
  String _paymentFilter = 'ALL';
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SaleProvider>().load(),
    );
  }

  List<Sale> _filtered(List<Sale> sales) {
    var list = sales;
    if (_filter == 'OVERDUE') {
      list = list.where((s) => s.isOverdue).toList();
    } else if (_filter != 'ALL') {
      list = list.where((s) => s.status == _filter).toList();
    }
    if (_paymentFilter != 'ALL') {
      list = list
          .where((s) => paymentStatus(total: s.total, paid: s.paidAmount) == _paymentFilter)
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (s) =>
                s.invoiceNumber.toLowerCase().contains(q) ||
                s.customerName.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SaleProvider>();
    final filtered = _filtered(sp.sales);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sales_fab',
        onPressed: () => context.push('/pos'),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: () => context.read<SaleProvider>().load(),
          child: sp.isLoading && sp.sales.isEmpty
              ? const LoadingView()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ResponsiveGrid(
                      columns: 2,
                      spacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        KpiCard.currency(
                          label: 'This Month',
                          value: sp.thisMonthTotal,
                          icon: Icons.calendar_month_outlined,
                          color: AppColors.orange,
                        ),
                        KpiCard.currency(
                          label: 'Receivable',
                          value: sp.totalReceivable,
                          icon: Icons.call_received,
                          color: AppColors.warning,
                        ),
                        KpiCard(
                          label: 'Total Invoices',
                          value: '${sp.sales.length}',
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.info,
                        ),
                        KpiCard(
                          label: 'Overdue',
                          value: '${sp.overdueCount}',
                          icon: Icons.error_outline,
                          color: AppColors.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SearchField(
                      hint: 'Search invoice # or customer',
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['ALL', 'DRAFT', 'CONFIRMED', 'OVERDUE'].map((
                          f,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppFilterChip(
                              label: f,
                              selected: _filter == f,
                              onTap: () => setState(() => _filter = f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['ALL', 'PAID', 'PARTIAL', 'UNPAID'].map((
                          f,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppFilterChip(
                              label: f == 'ALL' ? 'All Payments' : f[0] + f.substring(1).toLowerCase(),
                              selected: _paymentFilter == f,
                              onTap: () => setState(() => _paymentFilter = f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No invoices found',
                        message: 'Create your first invoice to get started.',
                      )
                    else
                      ...filtered.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            onTap: s.pendingSync
                                ? () => showAppSnackBar(context, t('syncingPending'))
                                : () => context.push('/invoice/${s.id}'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.invoiceNumber,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${s.customerName.isNotEmpty ? s.customerName : 'Walk-in'} · ${Formatters.dateShort(s.saleDate)}',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (s.createdAt != null)
                                        Text(
                                          'Added ${Formatters.dateShort(s.createdAt)}',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatters.currency(s.total),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    StatusBadge(
                                      label: s.pendingSync
                                          ? t('pendingSync')
                                          : (s.isOverdue ? 'OVERDUE' : s.status),
                                    ),
                                    const SizedBox(height: 4),
                                    StatusBadge(
                                      label: paymentStatus(total: s.total, paid: s.paidAmount),
                                    ),
                                  ],
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
