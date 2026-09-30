import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/calendar/nepal_time.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../banking/presentation/providers/banking_provider.dart';
import '../../data/models/sale_model.dart';
import '../../data/services/sale_service.dart';

const _methods = {'CASH': 'Cash', 'BANK': 'Bank', 'ESEWA': 'eSewa', 'KHALTI': 'Khalti'};

/// Receive (part of) what's still due on [sale]. Returns the server's message
/// when a payment was recorded, null if the sheet was closed.
Future<String?> showReceivePaymentSheet(BuildContext context, Sale sale) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReceivePaymentSheet(sale: sale),
  );
}

class _ReceivePaymentSheet extends StatefulWidget {
  final Sale sale;
  const _ReceivePaymentSheet({required this.sale});

  @override
  State<_ReceivePaymentSheet> createState() => _ReceivePaymentSheetState();
}

class _ReceivePaymentSheetState extends State<_ReceivePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(text: widget.sale.dueAmount.toStringAsFixed(2));
  final _noteController = TextEditingController();
  String _method = 'CASH';
  int? _bankAccountId;
  bool _saving = false;

  double get _due => widget.sale.dueAmount;
  double get _amount => double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BankingProvider>().load());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final message = await SaleService().receivePayment(
        widget.sale.id,
        amount: _amount,
        method: _method,
        bankAccount: _method == 'CASH' ? null : _bankAccountId,
        date: NepalTime.now(),
        note: _noteController.text.trim(),
      );
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e is ApiException ? e.message : "Couldn't record the payment", isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<BankingProvider>().accounts;
    final left = _due - _amount;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHeader(title: 'Receive Payment'),
                const SizedBox(height: 4),
                Text('Invoice ${widget.sale.invoiceNumber} · Due ${Formatters.currency(_due)}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount received',
                    prefixText: 'Rs ',
                    helperText: _amount > 0 && left > 0.005 ? '${Formatters.currency(left)} will still be due' : null,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (_) {
                    if (_amount <= 0) return 'Enter an amount above 0';
                    if (_amount > _due + 0.005) return 'Only ${Formatters.currency(_due)} is due';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: [for (final m in _methods.entries) DropdownMenuItem(value: m.key, child: Text(m.value))],
                  onChanged: (v) => setState(() => _method = v ?? 'CASH'),
                ),
                if (_method != 'CASH' && accounts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: _bankAccountId,
                    decoration: const InputDecoration(labelText: 'Into account'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Not linked to an account')),
                      for (final a in accounts)
                        DropdownMenuItem<int?>(value: a.id, child: Text(a.bankName.isNotEmpty ? a.bankName : a.accountName)),
                    ],
                    onChanged: (v) => setState(() => _bankAccountId = v),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Receive ${Formatters.currency(_amount)}',
                  isLoading: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
