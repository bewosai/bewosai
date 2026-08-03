import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/models/party_model.dart';
import '../providers/party_provider.dart';
import 'party_payment_form.dart';

class PartyLedgerScreen extends StatefulWidget {
  final int partyId;
  const PartyLedgerScreen({super.key, required this.partyId});

  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  PartyLedger? _ledger;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ledger = await context.read<PartyProvider>().ledger(widget.partyId);
    if (mounted) {
      setState(() {
        _ledger = ledger;
        _loading = false;
      });
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'SALE': return Icons.receipt_long_outlined;
      case 'RECEIPT':
      case 'PAYMENT_IN': return Icons.arrow_downward;
      case 'SALE_RETURN': return Icons.undo;
      case 'PURCHASE': return Icons.shopping_bag_outlined;
      case 'PAYMENT_OUT': return Icons.arrow_upward;
      case 'PURCHASE_RETURN': return Icons.undo;
      default: return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _ledger;
    return Scaffold(
      appBar: AppBar(title: Text(l?.party.name ?? 'Party Ledger'), actions: const [HomeLogoButton()]),
      floatingActionButton: l == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'party_ledger_fab',
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Add Payment'),
              onPressed: () async {
                await showPartyPaymentForm(
                  context,
                  paymentType: l.party.isCustomer ? 'IN' : 'OUT',
                  party: l.party,
                );
                if (mounted) _load();
              },
            ),
      body: _loading
          ? const LoadingView()
          : l == null
              ? const EmptyState(icon: Icons.error_outline, title: 'Could not load ledger')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(child: _summaryCard('Total Debit', l.totalDebit, AppColors.error)),
                          const SizedBox(width: 10),
                          Expanded(child: _summaryCard('Total Credit', l.totalCredit, AppColors.success)),
                          const SizedBox(width: 10),
                          Expanded(child: _summaryCard('Balance', l.closingBalance, l.closingBalance >= 0 ? AppColors.warning : AppColors.success)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (l.entries.isEmpty)
                        const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions yet')
                      else
                        ...l.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(color: AppColors.navy50, borderRadius: BorderRadius.circular(10)),
                                      child: Icon(_iconFor(e.type), size: 18, color: AppColors.navy600),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            StatusBadge(label: e.type, color: AppColors.navy500),
                                            const SizedBox(width: 6),
                                            Text(e.ref, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                          ]),
                                          Text(Formatters.dateShort(e.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (e.debit > 0) Text('+${Formatters.currency(e.debit)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                                        if (e.credit > 0) Text('-${Formatters.currency(e.credit)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                                        Text('Bal: ${Formatters.currency(e.balance)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(Formatters.currency(value), style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
        ],
      ),
    );
  }
}
