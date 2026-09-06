import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/calendar/nepali_calendar_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/pdf/bill_pdf.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/sale_model.dart';
import '../../data/services/sale_service.dart';
import '../providers/sale_provider.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int saleId;
  const InvoiceDetailScreen({super.key, required this.saleId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _service = SaleService();
  Sale? _sale;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _sale = await _service.get(widget.saleId);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancelInvoice() async {
    final saleProvider = context.read<SaleProvider>();
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: 'Cancel this invoice?',
      message: 'The invoice will be marked as cancelled.',
      confirmLabel: 'Cancel Invoice',
    );
    if (!confirmed) return;
    final ok = await saleProvider.cancel(widget.saleId);
    if (!mounted) return;
    if (ok) {
      _load();
      showAppSnackBar(context, 'Invoice cancelled');
    }
  }

  void _shareWhatsApp() {
    final s = _sale;
    if (s == null) return;
    final text = Uri.encodeComponent(
      'Invoice ${s.invoiceNumber}\n'
      'Customer: ${s.customerName.isNotEmpty ? s.customerName : 'Walk-in'}\n'
      'Total: ${Formatters.currency(s.total)}\n'
      'Paid: ${Formatters.currency(s.paidAmount)}\n'
      'Due: ${Formatters.currency(s.dueAmount)}',
    );
    final phone = s.partyPhone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$phone?text=$text');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _print() {
    final s = _sale;
    if (s == null) return;
    final business = context.read<AuthProvider>().currentBusiness;
    // Mode of Payment (channel) and Bill Type (paid now vs owed) are
    // separate facts — see the Cash/Credit toggle on the form itself.
    final paymentModeLabel = AppConstants.paymentMethodLabels[s.paymentMethod] ?? s.paymentMethod;
    final billType = s.paidAmount <= 0 && s.dueAmount > 0 ? 'Credit' : 'Cash';
    showBillPrintDialog(
      context,
      documentTitle: 'Tax Invoice',
      data: BillPdfData(
        businessName: business?.name ?? '',
        businessPhone: business?.phone ?? '',
        businessAddress: business?.address ?? '',
        businessPan: business?.panNumber ?? '',
        businessVat: business?.vatNumber ?? '',
        number: s.invoiceNumber,
        partyLabel: 'Customer',
        partyName: s.customerName.isNotEmpty ? s.customerName : 'Walk-in',
        partyPan: s.partyPan,
        partyAddress: s.partyAddress,
        partyPhone: s.partyPhone,
        date: Formatters.date(s.saleDate),
        miti: s.saleDate != null ? NepaliCalendarService.fromDateTime(s.saleDate!) : null,
        dueDate: s.dueDate != null ? Formatters.date(s.dueDate) : null,
        paymentModeLabel: paymentModeLabel,
        billType: billType,
        items: s.items
            .map(
              (i) => BillPdfItem(
                name: i.productName,
                hsCode: i.hsCode,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                discountAmount: i.discountAmount,
                total: i.total,
              ),
            )
            .toList(),
        subtotal: s.subtotal,
        discount: s.discount,
        taxRate: s.taxRate,
        taxAmount: s.taxAmount,
        total: s.total,
        paidAmount: s.paidAmount,
        dueAmount: s.dueAmount,
        notes: s.notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _sale;
    return Scaffold(
      appBar: AppBar(
        title: Text(s?.invoiceNumber ?? 'Invoice'),
        actions: [
          if (s != null) ...[
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: _print,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareWhatsApp,
            ),
            if (s.status != 'CANCELLED')
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/pos?edit=${s.id}').then((_) => _load()),
              ),
          ],
          const HomeLogoButton(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: ResponsiveBody(
        child: _loading
            ? const LoadingView()
            : _error != null
            ? EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load invoice',
                message: _error,
                action: PrimaryButton(
                  label: 'Retry',
                  expand: false,
                  onPressed: _load,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppSectionCard(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              s!.invoiceNumber,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: s.isOverdue ? 'OVERDUE' : s.status,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.customerName.isNotEmpty
                            ? s.customerName
                            : 'Walk-in Customer',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (s.partyPhone.isNotEmpty)
                        Text(
                          s.partyPhone,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Date: ${Formatters.date(s.saleDate)}${s.dueDate != null ? ' · Due: ${Formatters.date(s.dueDate)}' : ''}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoStrip(
                    invoiceNumber: s.invoiceNumber,
                    dueDate: s.dueDate != null ? Formatters.date(s.dueDate) : '—',
                    totalDue: Formatters.currency(s.dueAmount),
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    title: 'Items',
                    children: [
                      // Column headers once, like the printed invoice's
                      // S.N./Name/Qty/Rate/Amount table — so each item row
                      // below can be a single line instead of stacking the
                      // name above a separate "qty × price" line.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const SizedBox(width: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Item',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Qty',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Rate',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Amount',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 14),
                      ...s.items.asMap().entries.map((e) {
                        final i = e.key;
                        final item = e.value;
                        final isLast = i == s.items.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Formatters.amount(item.quantity),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  Formatters.currency(item.unitPrice),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  Formatters.currency(item.total),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSectionCard(
                    children: [
                      _row('Subtotal', Formatters.currency(s.subtotal)),
                      _row('Discount', '- ${Formatters.currency(s.discount)}'),
                      if (s.taxAmount > 0)
                        _row(
                          'VAT (${Formatters.amount(s.taxRate)}%)',
                          Formatters.currency(s.taxAmount),
                        ),
                      const Divider(height: 20),
                      _row('Total', Formatters.currency(s.total), bold: true),
                      _row('Paid', Formatters.currency(s.paidAmount)),
                      _row(
                        'Balance Due',
                        Formatters.currency(s.dueAmount),
                        color: s.dueAmount > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Payment Method: ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Flexible(
                            child: Text(
                              AppConstants.paymentMethodLabels[s.paymentMethod] ?? s.paymentMethod,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (s.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppSectionCard(title: 'Notes', children: [Text(s.notes)]),
                  ],
                  if (s.status != 'CANCELLED') ...[
                    const SizedBox(height: 20),
                    DangerButton(
                      label: 'Cancel Invoice',
                      onPressed: _cancelInvoice,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  /// Three-column highlight band (Invoice # / Due Date / Total Due) shown
  /// right below the invoice header — puts the facts a business owner
  /// checks first (which invoice, when it's due, how much is still owed)
  /// in one glanceable strip instead of scattered through smaller text.
  Widget _infoStrip({
    required String invoiceNumber,
    required String dueDate,
    required String totalDue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        gradient: AppColors.navyGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _infoStripCell('INVOICE #', invoiceNumber)),
            const VerticalDivider(color: Colors.white24, width: 1, indent: 4, endIndent: 4),
            Expanded(child: _infoStripCell('DUE DATE', dueDate)),
            const VerticalDivider(color: Colors.white24, width: 1, indent: 4, endIndent: 4),
            Expanded(child: _infoStripCell('TOTAL DUE', totalDue)),
          ],
        ),
      ),
    );
  }

  Widget _infoStripCell(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
