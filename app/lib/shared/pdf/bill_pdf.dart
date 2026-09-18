import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/amount_in_words.dart';
import '../../core/utils/formatters.dart';
import '../../core/calendar/nepal_time.dart';

/// One line item on a printed bill — shared shape for both Sale items and
/// Purchase items so [buildBillPdf] doesn't need to know which one it is.
class BillPdfItem {
  final String name;
  final String hsCode;
  final double quantity;
  // Which unit this line was billed in (e.g. "Piece" vs the product's
  // primary "Box") — blank when the product has no secondary unit
  // configured, so the printed Quantity column just shows the number.
  final String unitLabel;
  final double unitPrice;
  final double discountAmount;
  final double total;

  const BillPdfItem({
    required this.name,
    this.hsCode = '',
    required this.quantity,
    this.unitLabel = '',
    required this.unitPrice,
    this.discountAmount = 0,
    required this.total,
  });
}

/// Everything [buildBillPdf] needs to render a Sale invoice or a Purchase
/// bill — the caller supplies the labels so the same layout serves both.
/// Mirrors the React print template (SalesPage/PurchasesPage PrintModal) so
/// a bill looks the same whether it was printed from the phone or the web.
class BillPdfData {
  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String businessPan;
  final String businessVat;
  final String number;
  final String partyLabel; // 'Customer' for a sale, 'Supplier' for a purchase
  final String partyName;
  final String partyPan;
  final String partyAddress;
  final String partyPhone;
  final String date;
  final String? miti; // BS date, already formatted
  final String? dueDate;
  final String paymentModeLabel;
  final String billType; // 'Cash' or 'Credit' — see the Cash/Credit toggle on the form
  final List<BillPdfItem> items;
  final double subtotal;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double total;
  final double paidAmount;
  final double dueAmount;
  final String notes;

  const BillPdfData({
    this.businessName = '',
    this.businessPhone = '',
    this.businessAddress = '',
    this.businessPan = '',
    this.businessVat = '',
    required this.number,
    required this.partyLabel,
    required this.partyName,
    this.partyPan = '',
    this.partyAddress = '',
    this.partyPhone = '',
    required this.date,
    this.miti,
    this.dueDate,
    this.paymentModeLabel = 'Cash',
    this.billType = 'Cash',
    required this.items,
    required this.subtotal,
    required this.discount,
    this.taxRate = 0,
    this.taxAmount = 0,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    this.notes = '',
  });
}

/// Builds a one-page A4 PDF for [data] — a colored-header business bill
/// (accent bar, BILL TO block, ruled items table, boxed Amount in Words,
/// boxed Terms & Conditions / Seal and Signature, thank-you footer bar),
/// matching the classic printable-invoice layout Nepali small businesses
/// already expect (as opposed to a plain in-app-styled card). Always
/// carries a small "*Proforma Invoice" note near the totals — permanent,
/// not a per-print choice (see printBillPdf/showBillPrintDialog).
Future<pw.Document> buildBillPdf({
  required BillPdfData data,
  required String documentTitle,
}) async {
  final doc = pw.Document();
  final accent = PdfColor.fromHex('#f97316'); // Bewosai brand orange
  final black = PdfColors.grey900;
  final grey600 = PdfColors.grey600;
  final grey400 = PdfColors.grey400;
  final zebra = PdfColor.fromHex('#fafafa');
  final boxBorder = pw.BoxDecoration(border: pw.Border.all(width: 0.8, color: grey400));

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header bar — business name + document title on a solid
            // accent band, the way a printed letterhead would.
            pw.Container(
              color: accent,
              padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    data.businessName,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  ),
                  pw.Text(
                    documentTitle.toUpperCase(),
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),

            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (data.businessAddress.isNotEmpty)
                    _labeledLine('Company Address', data.businessAddress, accent),
                  if (data.businessPhone.isNotEmpty)
                    _labeledLine('Contact Details', data.businessPhone, accent),
                  if (data.businessPan.isNotEmpty || data.businessVat.isNotEmpty)
                    _labeledLine(
                      'PAN / VAT',
                      [if (data.businessPan.isNotEmpty) data.businessPan, if (data.businessVat.isNotEmpty) data.businessVat].join('   '),
                      accent,
                    ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),
            pw.Divider(height: 1, thickness: 0.8, color: grey400, indent: 24, endIndent: 24),
            pw.SizedBox(height: 12),

            // BILL TO (left) + Date / Number / Due date / Payment mode (right)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 24),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accent, letterSpacing: 1)),
                        pw.SizedBox(height: 4),
                        pw.Text(data.partyName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: black)),
                        if (data.partyAddress.isNotEmpty)
                          pw.Text(data.partyAddress, style: pw.TextStyle(fontSize: 8.5, color: grey600)),
                        if (data.partyPhone.isNotEmpty)
                          pw.Text('Phone: ${data.partyPhone}', style: pw.TextStyle(fontSize: 8.5, color: grey600)),
                        if (data.partyPan.isNotEmpty)
                          pw.Text('PAN/VAT: ${data.partyPan}', style: pw.TextStyle(fontSize: 8.5, color: grey600)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _metaRow('DATE', data.date, black),
                        if (data.miti != null) _metaRow('MITI', data.miti!, black),
                        _metaRow('${documentTitle.toUpperCase()} NO.', data.number, black, bold: true),
                        if (data.dueDate != null) _metaRow('DUE DATE', data.dueDate!, black),
                        _metaRow('PAYMENT MODE', data.paymentModeLabel, black),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Items table
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 24),
              child: pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(0.6),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1.3),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: accent),
                    children: [
                      _headCell('SL NO'),
                      _headCell('ITEM'),
                      _headCell('QUANTITY', align: pw.TextAlign.right),
                      _headCell('PRICE/UNIT', align: pw.TextAlign.right),
                      _headCell('TAX RATE', align: pw.TextAlign.right),
                      _headCell('TOTAL', align: pw.TextAlign.right),
                    ],
                  ),
                  for (var i = 0; i < data.items.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : zebra),
                      children: [
                        _cell('${i + 1}'),
                        _cell(
                          data.items[i].hsCode.isEmpty
                              ? data.items[i].name
                              : '${data.items[i].name}\nHSN: ${data.items[i].hsCode}',
                          bold: true,
                        ),
                        _cell(
                          data.items[i].unitLabel.isEmpty
                              ? Formatters.amount(data.items[i].quantity)
                              : '${Formatters.amount(data.items[i].quantity)} ${data.items[i].unitLabel}',
                          align: pw.TextAlign.right,
                        ),
                        _cell(data.items[i].unitPrice.toStringAsFixed(2), align: pw.TextAlign.right),
                        _cell(data.taxRate > 0 ? '${Formatters.amount(data.taxRate)}%' : '--', align: pw.TextAlign.right),
                        _cell(data.items[i].total.toStringAsFixed(2), align: pw.TextAlign.right, bold: true),
                      ],
                    ),
                  // A few zebra-striped blank rows so a short bill still
                  // reads like a real invoice book instead of the table
                  // just stopping.
                  for (var i = data.items.length; i < (data.items.length < 3 ? 3 : data.items.length); i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : zebra),
                      children: [_cell(' ', pad: 10), _cell(''), _cell(''), _cell(''), _cell(''), _cell('')],
                    ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 24),
              child: pw.Divider(height: 1, thickness: 0.8, color: grey400),
            ),

            pw.SizedBox(height: 16),

            // Amount in words (left) + totals (right)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 24),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      decoration: boxBorder,
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.Text('AMOUNT IN WORDS', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: accent, letterSpacing: 0.8)),
                          pw.SizedBox(height: 4),
                          pw.Text('Rs. ${amountInWords(data.total)}', style: pw.TextStyle(fontSize: 9, color: black)),
                          if (data.notes.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.RichText(text: pw.TextSpan(style: pw.TextStyle(fontSize: 8.5, color: black), children: [
                              pw.TextSpan(text: 'Remarks: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.TextSpan(text: data.notes),
                            ])),
                          ],
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _totalLine('SUBTOTAL', Formatters.amount(data.subtotal), grey400, black),
                        if (data.discount > 0) _totalLine('DISCOUNT', data.discount.toStringAsFixed(2), grey400, black),
                        if (data.taxAmount > 0)
                          _totalLine('VAT (${Formatters.amount(data.taxRate)}%)', data.taxAmount.toStringAsFixed(2), grey400, black),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6),
                          decoration: pw.BoxDecoration(color: accent),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8),
                                child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(right: 8),
                                child: pw.Text(data.total.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                              ),
                            ],
                          ),
                        ),
                        if (data.paidAmount > 0) ...[
                          pw.SizedBox(height: 4),
                          _totalLine('PAID', data.paidAmount.toStringAsFixed(2), grey400, black),
                        ],
                        if (data.dueAmount != 0)
                          _totalLine(
                            data.dueAmount < 0 ? 'ADVANCE (OVERPAID)' : 'DUE',
                            data.dueAmount.abs().toStringAsFixed(2),
                            grey400, black, bold: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Terms & Conditions (left) + Seal and Signature (right)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 24),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      height: 90,
                      decoration: boxBorder,
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TERMS AND CONDITIONS', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: black)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Goods once sold will not be taken back or exchanged.\nAll disputes are subject to local jurisdiction only.',
                            style: pw.TextStyle(fontSize: 8, color: grey600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Container(
                    width: 200,
                    height: 90,
                    decoration: boxBorder,
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text('SEAL AND SIGNATURE', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: black)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            pw.Center(
              child: pw.Text(
                'THANKS FOR DOING BUSINESS WITH US. PLEASE VISIT US AGAIN !!!',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: black),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('*Proforma Invoice   ·   Print Date & Time: ${_now()}', style: pw.TextStyle(fontSize: 7, color: grey600)),
            ),
            pw.SizedBox(height: 14),

            // Footer bar
            pw.Container(
              color: accent,
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Powered by Bewosai', style: pw.TextStyle(fontSize: 8, color: PdfColors.white)),
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc;
}

String _now() {
  final n = NepalTime.now();
  final d = n.day.toString().padLeft(2, '0');
  final m = n.month.toString().padLeft(2, '0');
  final hour = n.hour % 12 == 0 ? 12 : n.hour % 12;
  final min = n.minute.toString().padLeft(2, '0');
  final ampm = n.hour >= 12 ? 'PM' : 'AM';
  return '$d/$m/${n.year} $hour:$min $ampm';
}

/// "Label: value" line under the header bar (Company Address / Contact
/// Details), in the accent color the way the reference template prints
/// its own placeholder labels.
pw.Widget _labeledLine(String label, String value, PdfColor accent) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.RichText(
      text: pw.TextSpan(style: pw.TextStyle(fontSize: 8.5, color: accent), children: [
        pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TextSpan(text: value),
      ]),
    ),
  );
}

/// Right-aligned "LABEL value" row used for Date/Number/Due date/Payment
/// mode next to the BILL TO block.
pw.Widget _metaRow(String label, String value, PdfColor color, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.RichText(
      text: pw.TextSpan(style: pw.TextStyle(fontSize: 8.5, color: color), children: [
        pw.TextSpan(text: '$label: ', style: pw.TextStyle(color: PdfColors.grey600)),
        pw.TextSpan(text: value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]),
    ),
  );
}

pw.Widget _headCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    ),
  );
}

/// One underlined "LABEL .......... value" row in the totals box, echoing
/// the reference template's fill-in-the-line look for Subtotal/Discount.
pw.Widget _totalLine(String label, String value, PdfColor lineColor, PdfColor textColor, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: textColor)),
            pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: textColor)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 0.6, color: lineColor),
      ],
    ),
  );
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  pw.TextAlign align = pw.TextAlign.left,
  double pad = 5,
}) {
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: pad, horizontal: 4),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: PdfColors.grey900),
    ),
  );
}

/// Opens the OS print/share sheet for [data] via `package:printing`.
Future<void> printBillPdf({
  required BillPdfData data,
  required String documentTitle,
}) async {
  await Printing.layoutPdf(
    onLayout: (format) async {
      final doc = await buildBillPdf(data: data, documentTitle: documentTitle);
      return doc.save();
    },
  );
}

/// Opens the print sheet directly for [data] — kept as a separate entry
/// point (rather than inlining printBillPdf at call sites) since it used to
/// ask Proforma-or-not first; that choice is gone now that every bill
/// always carries the "*Proforma Invoice" note (see buildBillPdf), but the
/// name is kept so callers don't need to change.
Future<void> showBillPrintDialog(
  BuildContext context, {
  required BillPdfData data,
  required String documentTitle,
}) async {
  await printBillPdf(data: data, documentTitle: documentTitle);
}
