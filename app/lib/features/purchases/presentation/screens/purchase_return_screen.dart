import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/models/purchase_model.dart';
import '../providers/purchase_provider.dart';
import '../../../../core/calendar/nepal_time.dart';

/// Mirrors the web app's Purchase Return page: pick a bill, pick which line
/// items and how much of each to return, stock is decremented automatically
/// server-side (goods going back to the supplier) — see
/// PurchaseReturnSerializer.create() on the backend.
class PurchaseReturnScreen extends StatefulWidget {
  const PurchaseReturnScreen({super.key});

  @override
  State<PurchaseReturnScreen> createState() => _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends State<PurchaseReturnScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().loadReturns();
      // Needed by the "pick a bill" sheet in the form screen.
      final pp = context.read<PurchaseProvider>();
      if (pp.purchases.isEmpty) pp.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PurchaseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Return'),
        actions: const [HomeLogoButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'purchase_return_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _PurchaseReturnFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Return'),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: () => context.read<PurchaseProvider>().loadReturns(),
          child: pp.isLoadingReturns && pp.returns.isEmpty
              ? const LoadingView()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (pp.returns.isEmpty)
                      const EmptyState(
                        icon: Icons.assignment_return_outlined,
                        title: 'No return records found',
                        message: 'Product returns to suppliers and automatic stock adjustment.',
                      )
                    else
                      ...pp.returns.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.orangeLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.assignment_return_outlined, color: AppColors.orangeDark),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bill: ${r.originalPurchaseNumber.isNotEmpty ? r.originalPurchaseNumber : r.originalPurchase}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${Formatters.date(r.returnDate)} · ${r.reason.isNotEmpty ? r.reason : 'No reason given'}',
                                        style: TextStyle(fontSize: 12, color: AppColors.navy500),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '- ${Formatters.currency(r.amount)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('Stock Adjusted', style: TextStyle(fontSize: 11, color: AppColors.success)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ReturnLine {
  final int? purchaseItemId;
  final int? productId;
  final String productName;
  final double maxQuantity;
  final double unitPrice;
  final qtyController = TextEditingController(text: '0');

  _ReturnLine({
    this.purchaseItemId,
    this.productId,
    required this.productName,
    required this.maxQuantity,
    required this.unitPrice,
  });

  double get qty => double.tryParse(qtyController.text) ?? 0;
}

class _PurchaseReturnFormScreen extends StatefulWidget {
  const _PurchaseReturnFormScreen();

  @override
  State<_PurchaseReturnFormScreen> createState() => _PurchaseReturnFormScreenState();
}

class _PurchaseReturnFormScreenState extends State<_PurchaseReturnFormScreen> {
  Purchase? _originalPurchase;
  List<_ReturnLine> _lines = [];
  DateTime _returnDate = NepalTime.now();
  final _reasonController = TextEditingController();
  bool _loadingItems = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    for (final l in _lines) {
      l.qtyController.dispose();
    }
    super.dispose();
  }

  double get _returnAmount => _lines.fold(0.0, (sum, l) => sum + (l.qty * l.unitPrice));

  Future<void> _pickBill() async {
    final purchases = context.read<PurchaseProvider>().purchases;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SearchSheet<Purchase>(
        title: 'Select Original Bill',
        items: purchases,
        labelBuilder: (p) => p.billNumber,
        subtitleBuilder: (p) => '${p.supplierName} · ${Formatters.currency(p.total)}',
        onSelected: _selectBill,
      ),
    );
  }

  Future<void> _selectBill(Purchase p) async {
    setState(() {
      _originalPurchase = p;
      _lines = [];
      _loadingItems = true;
      _error = null;
    });
    // The list response doesn't reliably carry every item — fetch full detail.
    final full = await context.read<PurchaseProvider>().getPurchase(p.id);
    final items = (full ?? p).items;
    if (!mounted) return;
    setState(() {
      _lines = items
          .map((it) => _ReturnLine(
                purchaseItemId: it.id,
                productId: it.product,
                productName: it.productName,
                maxQuantity: it.quantity,
                unitPrice: it.unitPrice,
              ))
          .toList();
      _loadingItems = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await AppDatePicker.pick(
      context,
      initialDate: _returnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _returnDate = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_originalPurchase == null) {
      setState(() => _error = 'Select the original purchase bill.');
      return;
    }
    final returnedLines = _lines.where((l) => l.qty > 0).toList();
    if (returnedLines.isEmpty) {
      setState(() => _error = 'Enter a return quantity for at least one item.');
      return;
    }

    setState(() => _saving = true);
    final purchaseReturn = PurchaseReturn(
      id: 0,
      originalPurchase: _originalPurchase!.id,
      originalPurchaseNumber: _originalPurchase!.billNumber,
      returnDate: _returnDate,
      reason: _reasonController.text.trim(),
      amount: _returnAmount,
      items: returnedLines
          .map((l) => PurchaseReturnItem(
                purchaseItem: l.purchaseItemId,
                product: l.productId,
                productName: l.productName,
                quantity: l.qty,
                unitPrice: l.unitPrice,
              ))
          .toList(),
    );

    final ok = await context.read<PurchaseProvider>().createReturn(purchaseReturn);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
      showAppSnackBar(context, 'Purchase return recorded');
    } else {
      setState(() => _error = context.read<PurchaseProvider>().error ?? 'Failed to save.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Purchase Return'),
        actions: const [HomeLogoButton()],
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBgLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                    ],
                  ),
                ),
              ),
            AppSectionCard(
              children: [
                InkWell(
                  onTap: _pickBill,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Original Bill',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                    ),
                    child: Text(_originalPurchase?.billNumber ?? 'Select original bill'),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Return Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(Formatters.date(_returnDate)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingItems)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_lines.isNotEmpty) ...[
              const Text('Items to Return', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              AppSectionCard(
                children: [
                  for (var i = 0; i < _lines.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    _ReturnLineRow(line: _lines[i], onChanged: () => setState(() {})),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Return Amount', style: TextStyle(color: AppColors.navy500)),
                  Text(Formatters.currency(_returnAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reason', hintText: 'Reason for return…'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryButton(
            label: 'Record Return',
            isLoading: _saving,
            onPressed: _save,
          ),
        ),
      ),
    );
  }
}

class _ReturnLineRow extends StatelessWidget {
  final _ReturnLine line;
  final VoidCallback onChanged;

  const _ReturnLineRow({required this.line, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.productName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              Text('Purchased: ${Formatters.amount(line.maxQuantity)}', style: TextStyle(fontSize: 11, color: AppColors.navy500)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: TextField(
            controller: line.qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'Return Qty', isDense: true),
            onChanged: (v) {
              final parsed = double.tryParse(v) ?? 0;
              final clamped = parsed.clamp(0, line.maxQuantity);
              if (clamped != parsed) {
                line.qtyController.value = TextEditingValue(
                  text: Formatters.amount(clamped.toDouble()),
                  selection: TextSelection.collapsed(offset: Formatters.amount(clamped.toDouble()).length),
                );
              }
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}
