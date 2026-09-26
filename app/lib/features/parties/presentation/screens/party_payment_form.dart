import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../banking/presentation/providers/banking_provider.dart';
import '../../../purchases/presentation/providers/purchase_provider.dart';
import '../../../sales/presentation/providers/sale_provider.dart';
import '../../data/models/party_model.dart';
import '../providers/party_provider.dart';
import '../../../../core/calendar/nepal_time.dart';

/// Opens the Payment In / Payment Out entry sheet. If [party] is provided
/// (e.g. from the party ledger) it's preselected and locked; otherwise the
/// user searches for one, filtered to customers for IN / suppliers for OUT.
Future<void> showPartyPaymentForm(BuildContext context, {required String paymentType, Party? party}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PartyPaymentFormSheet(paymentType: paymentType, initialParty: party),
  );
}

class _PartyPaymentFormSheet extends StatefulWidget {
  final String paymentType; // IN or OUT
  final Party? initialParty;
  const _PartyPaymentFormSheet({required this.paymentType, this.initialParty});

  @override
  State<_PartyPaymentFormSheet> createState() => _PartyPaymentFormSheetState();
}

class _PartyPaymentFormSheetState extends State<_PartyPaymentFormSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Party? _party;
  DateTime _date = NepalTime.now();
  String _method = 'CASH';
  int? _bankAccountId;
  bool _saving = false;

  bool get _isIn => widget.paymentType == 'IN';

  @override
  void initState() {
    super.initState();
    _party = widget.initialParty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BankingProvider>().load();
    });
  }

  void _pickParty() {
    final provider = context.read<PartyProvider>();
    final list = _isIn ? provider.customers : provider.suppliers;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SearchSheet<Party>(
        title: _isIn ? 'Select Customer' : 'Select Supplier',
        items: list,
        labelBuilder: (p) => p.name,
        subtitleBuilder: (p) => p.phone,
        onSelected: (p) => setState(() => _party = p),
      ),
    );
  }

  Future<void> _submit() async {
    if (_party == null) {
      showAppSnackBar(context, 'Select a party', isError: true);
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      showAppSnackBar(context, 'Enter a valid amount', isError: true);
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<PartyProvider>();
    final ok = await provider.addPayment(PartyPayment(
      id: 0,
      party: _party!.id,
      partyName: _party!.name,
      paymentType: widget.paymentType,
      amount: amount,
      paymentMethod: _method,
      bankAccount: _method != 'CASH' ? _bankAccountId : null,
      date: _date,
      note: _noteController.text.trim(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      // The payment settles the oldest open bills: reload them so their dues
      // update now — and, for sales, so a reminder for a bill that's now fully
      // paid is cancelled (SaleProvider.load does that) instead of still firing.
      if (_isIn) {
        context.read<SaleProvider>().load();
      } else {
        context.read<PurchaseProvider>().load();
      }
      Navigator.pop(context);
      showAppSnackBar(context, _isIn ? 'Payment received' : 'Payment made');
    } else {
      showAppSnackBar(context, provider.error ?? 'Failed to save payment', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isIn ? AppColors.success : AppColors.error;
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: _isIn ? 'To Receive' : 'To Give'),
          Text(
            _isIn ? 'Record money received from a customer' : 'Record money paid to a supplier',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: widget.initialParty != null ? null : _pickParty,
            child: InputDecorator(
              decoration: InputDecoration(labelText: _isIn ? 'Customer *' : 'Supplier *', prefixIcon: const Icon(Icons.person_outline)),
              child: Text(_party?.name ?? 'Select ${_isIn ? 'customer' : 'supplier'}'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount *'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await AppDatePicker.pick(context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Text(Formatters.date(_date)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'ESEWA', child: Text('eSewa')),
              DropdownMenuItem(value: 'KHALTI', child: Text('Khalti')),
            ],
            onChanged: (v) => setState(() {
              _method = v ?? 'CASH';
              if (_method == 'CASH') _bankAccountId = null;
            }),
          ),
          if (_method != 'CASH') ...[
            const SizedBox(height: 12),
            Consumer<BankingProvider>(
              builder: (context, bp, _) {
                final accounts = bp.accounts;
                if (accounts.isEmpty) {
                  return Text(
                    'No bank accounts set up yet — add one from Banking to track this payment on a statement.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  );
                }
                return DropdownButtonFormField<int>(
                  initialValue: accounts.any((a) => a.id == _bankAccountId) ? _bankAccountId : null,
                  decoration: InputDecoration(labelText: _isIn ? 'Received Into Account' : 'Paid From Account'),
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.accountName))).toList(),
                  onChanged: (v) => setState(() => _bankAccountId = v),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(_isIn ? 'Save (Received)' : 'Save (Given)'),
          ),
        ],
      ),
    );
  }
}
