import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/calendar/nepal_time.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/return_lines.dart';
import '../../data/models/sale_model.dart';
import '../../data/services/sale_service.dart';
import '../providers/sale_provider.dart';

/// Sales Return: goods a customer sends back. Pick the invoice, choose how
/// much of each line comes back, and the stock is restored automatically on
/// the server (see SaleReturnSerializer.create). Mirrors [PurchaseReturnScreen].
class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SaleProvider>();
      sp.loadReturns();
      if (sp.sales.isEmpty) sp.load(); // the "pick an invoice" list
    });
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Return'),
        actions: const [HomeLogoButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sales_return_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SalesReturnFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Return'),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: () => context.read<SaleProvider>().loadReturns(),
          child: sp.isLoadingReturns && sp.returns.isEmpty
              ? const LoadingView()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (sp.returns.isEmpty && sp.returnsError != null)
                      EmptyState(
                        icon: Icons.error_outline,
                        title: 'Could not load returns',
                        message: sp.returnsError!,
                        action: PrimaryButton(
                          label: 'Retry',
                          expand: false,
                          onPressed: () => context.read<SaleProvider>().loadReturns(),
                        ),
                      )
                    else if (sp.returns.isEmpty)
                      const EmptyState(
                        icon: Icons.assignment_return_outlined,
                        title: 'No sales returns yet',
                        message: 'Goods customers send back, with the stock added back automatically.',
                      )
                    else
                      ...sp.returns.map(
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
                                        'Invoice: ${r.invoiceNumber.isNotEmpty ? r.invoiceNumber : r.originalSale}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${Formatters.date(r.returnDate)} · ${r.reason.isNotEmpty ? r.reason : 'No reason given'}',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                                    const Text('Stock Restored', style: TextStyle(fontSize: 11, color: AppColors.success)),
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

/// The "record a return" form. Public so the Dashboard's Quick Entry can open it
/// directly; [sale] pre-selects the invoice (e.g. from an invoice's own page).
class SalesReturnFormScreen extends StatefulWidget {
  final Sale? sale;
  const SalesReturnFormScreen({super.key, this.sale});

  @override
  State<SalesReturnFormScreen> createState() => _SalesReturnFormScreenState();
}

class _SalesReturnFormScreenState extends State<SalesReturnFormScreen> {
  Sale? _sale;
  List<ReturnLine> _lines = [];
  DateTime _returnDate = NepalTime.now();
  final _reasonController = TextEditingController();
  bool _loadingItems = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SaleProvider>();
      // Earlier returns decide how much of each line is still returnable, and
      // the invoice picker needs the sales list.
      sp.loadReturns().then((_) {
        if (mounted && _sale != null) _buildLines(_sale!);
      });
      if (sp.sales.isEmpty) sp.load();
      if (widget.sale != null) _selectSale(widget.sale!);
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _returnAmount => ReturnLine.totalOf(_lines);

  void _pickInvoice() {
    // Only real, live invoices: a cancelled one has nothing to return, and one
    // still queued offline doesn't exist on the server yet.
    final sales = context
        .read<SaleProvider>()
        .sales
        .where((s) => s.status == 'CONFIRMED' && !s.pendingSync)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SearchSheet<Sale>(
        title: 'Select Invoice',
        items: sales,
        labelBuilder: (s) => s.invoiceNumber,
        subtitleBuilder: (s) =>
            '${s.customerName.isNotEmpty ? s.customerName : 'Cash Sales'} · ${Formatters.currency(s.total)}',
        onSelected: _selectSale,
      ),
    );
  }

  Future<void> _selectSale(Sale s) async {
    setState(() {
      _sale = s;
      _loadingItems = true;
      _error = null;
    });
    // The list response doesn't reliably carry every item — fetch the full invoice.
    Sale full = s;
    try {
      full = await SaleService().get(s.id);
    } catch (_) {
      if (s.items.isEmpty && mounted) {
        setState(() {
          _loadingItems = false;
          _error = "Couldn't load this invoice's items. Check your connection and try again.";
        });
        return;
      }
    }
    if (!mounted) return;
    _sale = full;
    _buildLines(full);
  }

  void _buildLines(Sale sale) {
    final returned = <int, double>{};
    for (final r in context.read<SaleProvider>().returns) {
      if (r.originalSale != sale.id) continue;
      for (final it in r.items) {
        final id = it.saleItem;
        if (id != null) returned[id] = (returned[id] ?? 0) + it.quantity;
      }
    }
    for (final l in _lines) {
      l.dispose();
    }
    setState(() {
      _lines = sale.items.map((it) {
        final left = it.quantity - (returned[it.id] ?? 0);
        return ReturnLine(
          sourceItemId: it.id,
          productId: it.product,
          productName: it.productName,
          unitLabel: it.unitLabel,
          maxQuantity: left > 0 ? left : 0,
          unitPrice: ReturnLine.effectivePrice(quantity: it.quantity, unitPrice: it.unitPrice, total: it.total),
        );
      }).toList();
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
    if (_sale == null) {
      setState(() => _error = 'Select the invoice these goods were sold on.');
      return;
    }
    final returned = _lines.where((l) => l.qty > 0).toList();
    if (returned.isEmpty) {
      setState(() => _error = 'Enter a return quantity for at least one item.');
      return;
    }

    setState(() => _saving = true);
    final saleReturn = SaleReturn(
      id: 0,
      originalSale: _sale!.id,
      invoiceNumber: _sale!.invoiceNumber,
      returnDate: _returnDate,
      reason: _reasonController.text.trim(),
      amount: ReturnLine.totalOf(returned),
      items: returned
          .map((l) => SaleReturnItem(
                saleItem: l.sourceItemId,
                product: l.productId,
                productName: l.productName,
                quantity: l.qty,
                unitPrice: l.unitPrice,
              ))
          .toList(),
    );

    final provider = context.read<SaleProvider>();
    final ok = await provider.createReturn(saleReturn);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showAppSnackBar(context, 'Sales return recorded');
      Navigator.of(context).pop();
    } else {
      setState(() => _error = provider.error ?? 'Failed to save the return.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sales Return'),
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
                  onTap: _pickInvoice,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Original Invoice',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                    ),
                    child: Text(
                      _sale == null
                          ? 'Select invoice'
                          : '${_sale!.invoiceNumber} · ${_sale!.customerName.isNotEmpty ? _sale!.customerName : 'Cash Sales'}',
                    ),
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
            else if (_sale != null && _lines.isEmpty && _error == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This invoice has no items to return.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else if (_lines.isNotEmpty) ...[
              const Text('Items to Return', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              AppSectionCard(
                children: [
                  for (var i = 0; i < _lines.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    ReturnLineRow(
                      line: _lines[i],
                      billedLabel: 'Sold',
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Return Amount', style: TextStyle(color: AppColors.textSecondary)),
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
