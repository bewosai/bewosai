import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> sale;

  const InvoiceDetailScreen({super.key, required this.sale});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Map<String, dynamic>? _fullSale;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFull();
  }

  Future<void> _loadFull() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final id = widget.sale['id'];
      final res = await api.get('/sales/$id/');
      _fullSale = Map<String, dynamic>.from(res.data as Map? ?? {});
    } catch (_) {
      _fullSale = widget.sale;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sale['invoice_number']?.toString() ?? 'Invoice',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print',
            onPressed: _loading ? null : () => _printInvoice(settings),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share PDF',
            onPressed: _loading ? null : () => _sharePdf(settings),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildInvoiceView(settings),
    );
  }

  Widget _buildInvoiceView(AppSettings settings) {
    final sale = _fullSale ?? widget.sale;
    final items = List<Map<String, dynamic>>.from(
        (sale['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    final total = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(sale['paid_amount']?.toString() ?? '0') ?? 0;
    final balance = total - paid;
    final status = sale['status']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice header card
          _buildHeaderCard(sale, status, settings),
          const SizedBox(height: 16),

          // Items table
          _buildItemsTable(items, settings),
          const SizedBox(height: 16),

          // Totals
          _buildTotalsCard(total, paid, balance, sale, settings),
          const SizedBox(height: 16),

          // Action buttons
          _buildActionButtons(settings),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
      Map<String, dynamic> sale, String status, AppSettings settings) {
    final statusColor = switch (status) {
      'CONFIRMED' => AppColors.success,
      'DRAFT' => AppColors.info,
      'CANCELLED' => AppColors.error,
      'OVERDUE' => AppColors.error,
      _ => AppColors.navy500,
    };
    final statusBg = switch (status) {
      'CONFIRMED' => AppColors.successLight,
      'DRAFT' => AppColors.infoLight,
      'CANCELLED' || 'OVERDUE' => AppColors.errorLight,
      _ => AppColors.navy50,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale['invoice_number']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sale['sale_date']?.toString() ?? '',
                    style: const TextStyle(
                        color: AppColors.navy500, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
          ]),
          if ((sale['party_name'] ?? sale['customer_name'])?.toString().isNotEmpty ?? false) ...[
            const Divider(height: 20),
            _InfoRow(
              icon: Icons.person_rounded,
              label: 'Customer',
              value: (sale['party_name'] ?? sale['customer_name'])?.toString() ?? '',
            ),
            if ((sale['party_phone'] ?? '').toString().isNotEmpty)
              _InfoRow(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: sale['party_phone']?.toString() ?? '',
              ),
          ],
          if ((sale['payment_method'] ?? '').toString().isNotEmpty) ...[
            const Divider(height: 16),
            _InfoRow(
              icon: Icons.payments_rounded,
              label: 'Payment',
              value: _methodLabel(sale['payment_method']?.toString() ?? ''),
            ),
          ],
          if ((sale['notes'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 16, color: AppColors.navy500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sale['notes']?.toString() ?? '',
                    style: const TextStyle(
                        color: AppColors.navy500, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsTable(
      List<Map<String, dynamic>> items, AppSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('Items',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const Divider(height: 1),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Expanded(
                  flex: 3,
                  child: Text('ITEM',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy500,
                          letterSpacing: 0.5))),
              const Expanded(
                  child: Text('QTY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy500,
                          letterSpacing: 0.5))),
              const Expanded(
                  child: Text('PRICE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy500,
                          letterSpacing: 0.5))),
              Expanded(
                  child: Text('TOTAL',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy500,
                          letterSpacing: 0.5))),
            ]),
          ),
          const Divider(height: 1),
          ...items.map((item) {
            final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
            final price = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
            final disc = double.tryParse(item['discount_amount']?.toString() ?? '0') ?? 0;
            final lineTotal = (qty * price) - disc;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name']?.toString() ??
                                item['product']?.toString() ??
                                '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          if (disc > 0)
                            Text(
                              'Disc: ${settings.formatAmount(disc)}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.success),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        qty % 1 == 0
                            ? qty.toInt().toString()
                            : qty.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        settings.formatAmount(price),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        settings.formatAmount(lineTotal),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 1),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(double total, double paid, double balance,
      Map<String, dynamic> sale, AppSettings settings) {
    final subtotal  = double.tryParse(sale['subtotal']?.toString()    ?? '0') ?? 0;
    final discount  = double.tryParse(sale['discount']?.toString()    ?? '0') ?? 0;
    final taxRate   = double.tryParse(sale['tax_rate']?.toString()    ?? '0') ?? 0;
    final taxAmt    = double.tryParse(sale['tax_amount']?.toString()  ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _TotalRow(label: 'Subtotal', value: settings.formatAmount(subtotal), bold: false),
          if (discount > 0) ...[
            const SizedBox(height: 6),
            _TotalRow(label: 'Discount', value: '- ${settings.formatAmount(discount)}',
                color: AppColors.error, bold: false),
          ],
          if (taxRate > 0) ...[
            const SizedBox(height: 6),
            _TotalRow(label: 'VAT ${taxRate.toInt()}%',
                value: settings.formatAmount(taxAmt),
                color: AppColors.warning, bold: false),
          ],
          const Divider(height: 16),
          _TotalRow(label: 'Total', value: settings.formatAmount(total), bold: false),
          const SizedBox(height: 6),
          _TotalRow(label: 'Paid',  value: settings.formatAmount(paid),
              color: AppColors.success, bold: false),
          const Divider(height: 16),
          _TotalRow(
            label: balance > 0 ? 'Balance Due' : 'Overpaid',
            value: settings.formatAmount(balance.abs()),
            color: balance > 0 ? AppColors.error : AppColors.success,
            bold: true,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppSettings settings) {
    final sale    = _fullSale ?? widget.sale;
    final total   = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
    final paid    = double.tryParse(sale['paid_amount']?.toString() ?? '0') ?? 0;
    final balance = total - paid;

    return Column(children: [
      // Collect Payment — shown only when there's an outstanding balance
      if (balance > 0.005) ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showCollectPaymentSheet(settings),
            icon: const Icon(Icons.payments_rounded, size: 18),
            label: Text('Collect Payment  (${settings.formatAmount(balance)} due)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _printInvoice(settings),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Print'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: AppColors.orange),
              foregroundColor: AppColors.orange,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _sharePdf(settings),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _shareWhatsApp(settings),
          icon: const Icon(Icons.chat_rounded, size: 18),
          label: const Text('Send via WhatsApp'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }

  void _showCollectPaymentSheet(AppSettings settings) {
    final sale    = _fullSale ?? widget.sale;
    final total   = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
    final paid    = double.tryParse(sale['paid_amount']?.toString() ?? '0') ?? 0;
    final balance = total - paid;
    final saleId  = sale['id'];

    final amountCtrl = TextEditingController(
        text: balance.toStringAsFixed(2));
    final notesCtrl  = TextEditingController();
    String method    = sale['payment_method']?.toString() ?? 'CASH';
    bool saving      = false;

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
        builder: (ctx2, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                    height: 4, width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
                const Text('Collect Payment',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Balance due: ${settings.formatAmount(balance)}',
                    style: const TextStyle(color: AppColors.navy500, fontSize: 13)),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(
                    labelText: 'Amount Received',
                    prefixText: '${settings.currency} ',
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration:
                      const InputDecoration(labelText: 'Payment Method'),
                  items: methods.map((m) => DropdownMenuItem(
                        value: m['key'], child: Text(m['label']!))).toList(),
                  onChanged: (v) => ss(() => method = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final amt = double.tryParse(amountCtrl.text.trim());
                            if (amt == null || amt <= 0) return;
                            ss(() => saving = true);
                            try {
                              final api = context.read<ApiService>();
                              final newPaid = (paid + amt).clamp(0, total);
                              await api.patch('/sales/$saleId/', data: {
                                'paid_amount': newPaid,
                                'payment_method': method,
                                if (notesCtrl.text.trim().isNotEmpty)
                                  'notes': notesCtrl.text.trim(),
                              });
                              if (context.mounted) {
                                Navigator.pop(ctx2);
                                _loadFull();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${settings.formatAmount(amt)} collected!'),
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
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: saving
                        ? const Text('Saving...')
                        : const Text('Confirm Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareWhatsApp(AppSettings settings) async {
    final sale = _fullSale ?? widget.sale;
    final invoiceNum = sale['invoice_number']?.toString() ?? '';
    final customer   = (sale['party_name'] ?? sale['customer_name'])?.toString() ?? 'Customer';
    final total      = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
    final paid       = double.tryParse(sale['paid_amount']?.toString() ?? '0') ?? 0;
    final balance    = total - paid;
    final phone      = sale['party_phone']?.toString() ?? '';
    final date       = sale['sale_date']?.toString() ?? '';

    final msg = '''*Invoice: $invoiceNum*
Customer: $customer
Date: $date

Amount: ${settings.formatAmount(total)}
Paid: ${settings.formatAmount(paid)}${balance > 0 ? '\n*Balance Due: ${settings.formatAmount(balance)}*' : ''}

Thank you for your business! 🙏
_Powered by Bewosy_''';

    final encoded = Uri.encodeComponent(msg);
    final url = phone.isNotEmpty
        ? 'https://wa.me/$phone?text=$encoded'
        : 'https://wa.me/?text=$encoded';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not available on this device')));
    }
  }

  Future<pw.Document> _buildPdf(AppSettings settings) async {
    final sale = _fullSale ?? widget.sale;
    final items = List<Map<String, dynamic>>.from(
        (sale['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    final total = double.tryParse(sale['total']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(sale['paid_amount']?.toString() ?? '0') ?? 0;
    final balance = total - paid;

    final pdf = pw.Document();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        sale['invoice_number']?.toString() ?? '',
                        style: const pw.TextStyle(
                            fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: ${sale['sale_date'] ?? ''}',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Status: ${sale['status'] ?? ''}',
                        style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Customer info
            if ((sale['party_name'] ?? sale['customer_name']) != null)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bill To:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(
                      (sale['party_name'] ?? sale['customer_name'])?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 13)),
                  pw.SizedBox(height: 12),
                ],
              ),

            // Items table header
            pw.Container(
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(children: [
                pw.Expanded(
                    flex: 4,
                    child: pw.Text('ITEM',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10))),
                pw.Expanded(
                    child: pw.Text('QTY',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10))),
                pw.Expanded(
                    child: pw.Text('PRICE',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10))),
                pw.Expanded(
                    child: pw.Text('TOTAL',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10))),
              ]),
            ),

            // Item rows
            ...items.map((item) {
              final qty = double.tryParse(
                      item['quantity']?.toString() ?? '1') ?? 1;
              final price = double.tryParse(
                      item['unit_price']?.toString() ?? '0') ?? 0;
              final disc = double.tryParse(
                      item['discount_amount']?.toString() ?? '0') ?? 0;
              final lineTotal = (qty * price) - disc;
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 6, horizontal: 8),
                decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(
                            color: PdfColors.grey300))),
                child: pw.Row(children: [
                  pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                          item['product_name']?.toString() ?? '',
                          style: const pw.TextStyle(fontSize: 11))),
                  pw.Expanded(
                      child: pw.Text(
                          qty % 1 == 0
                              ? qty.toInt().toString()
                              : qty.toStringAsFixed(2),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 11))),
                  pw.Expanded(
                      child: pw.Text(
                          'Rs.${price.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 11))),
                  pw.Expanded(
                      child: pw.Text(
                          'Rs.${lineTotal.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11))),
                ]),
              );
            }).toList(),

            pw.SizedBox(height: 16),
            pw.Divider(),
            // Totals
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total: Rs.${total.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Paid: Rs.${paid.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Balance Due: Rs.${balance.abs().toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: balance > 0
                              ? PdfColors.red
                              : PdfColors.green)),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Center(
              child: pw.Text('Thank you for your business!',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey600)),
            ),
          ],
        );
      },
    ));

    return pdf;
  }

  Future<void> _printInvoice(AppSettings settings) async {
    final pdf = await _buildPdf(settings);
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: widget.sale['invoice_number']?.toString() ?? 'invoice',
    );
  }

  Future<void> _sharePdf(AppSettings settings) async {
    final pdf = await _buildPdf(settings);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          '${widget.sale['invoice_number']?.toString() ?? 'invoice'}.pdf',
    );
  }

  String _methodLabel(String method) {
    return switch (method) {
      'CASH' => 'Cash',
      'BANK' => 'Bank Transfer',
      'ESEWA' => 'eSewa',
      'KHALTI' => 'Khalti',
      'IME_PAY' => 'IME Pay',
      'MOBILE' => 'Mobile Banking',
      'CHEQUE' => 'Cheque',
      'CREDIT' => 'Credit',
      _ => method,
    };
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.navy500),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12, color: AppColors.navy500)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  final bool large;

  const _TotalRow({
    required this.label,
    required this.value,
    this.color = AppColors.navy500,
    required this.bold,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            color: bold ? null : AppColors.navy500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 18 : 14,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
