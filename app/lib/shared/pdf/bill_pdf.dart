import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/amount_in_words.dart';
import '../../core/utils/formatters.dart';

/// One line item on a printed bill — shared shape for both Sale items and
/// Purchase items so [buildBillPdf] doesn't need to know which one it is.
class BillPdfItem {
  final String name;
  final String hsCode;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double total;

  const BillPdfItem({
    required this.name,
    this.hsCode = '',
    required this.quantity,
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

/// Builds a one-page A4 PDF for [data] on a plain white page — a classic
/// bordered ledger-style Tax Invoice (matching the React print template's
/// layout) rather than a plain in-app-styled card, since that's the format
/// a Nepali business already expects a printed bill to look like. Always
/// carries a small "*Proforma Invoice" note near the totals — permanent,
/// not a per-print choice (see printBillPdf/showBillPrintDialog).
Future<pw.Document> buildBillPdf({
  required BillPdfData data,
  required String documentTitle,
}) async {
  final doc = pw.Document();
  final black = PdfColors.grey900;
  final grey600 = PdfColors.grey600;
  final ruleDark = const pw.BorderSide(width: 1.1, color: PdfColors.grey900);
  final ruleLight = pw.BorderSide(width: 0.5, color: PdfColors.grey400);

  pw.Widget section({required pw.Widget child, bool topBorder = false}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: ruleDark,
          top: topBorder ? ruleDark : pw.BorderSide.none,
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: child,
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        return pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.1, color: PdfColors.grey900)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Business header
              section(
                child: pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        data.businessName,
                        style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: black, decoration: pw.TextDecoration.underline),
                      ),
                      if (data.businessAddress.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(data.businessAddress, style: pw.TextStyle(fontSize: 9, color: black)),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Wrap(
                          alignment: pw.WrapAlignment.center,
                          spacing: 12,
                          children: [
                            if (data.businessPhone.isNotEmpty)
                              pw.Text('Ph.No: ${data.businessPhone}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: black)),
                            if (data.businessPan.isNotEmpty)
                              pw.Text('PAN No.: ${data.businessPan}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: black)),
                            if (data.businessVat.isNotEmpty)
                              pw.Text('VAT No.: ${data.businessVat}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: black)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // "Tax Invoice" heading
              section(
                child: pw.Center(
                  child: pw.Text(
                    documentTitle.toUpperCase(),
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: black, decoration: pw.TextDecoration.underline, letterSpacing: 1.2),
                  ),
                ),
              ),

              // Party + invoice meta
              section(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _kv('${data.partyLabel} Name', data.partyName, black, bold: true),
                          _kv('Pan / Vat No.', data.partyPan, black),
                          _kv('${data.partyLabel} Address', data.partyAddress, black),
                          _kv('${data.partyLabel} Cnt No.', data.partyPhone, black),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          _kv('Invoice No.', data.number, black, bold: true, alignEnd: true),
                          _kv('Date of Transaction', data.date, black, alignEnd: true),
                          if (data.miti != null) _kv('Miti of Transaction', data.miti!, black, alignEnd: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Mode of Payment / Bill Type
              section(
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(style: pw.TextStyle(fontSize: 9, color: black), children: [
                        const pw.TextSpan(text: 'Mode of Payment : '),
                        pw.TextSpan(text: data.paymentModeLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ]),
                    ),
                    pw.RichText(
                      text: pw.TextSpan(style: pw.TextStyle(fontSize: 9, color: black), children: [
                        const pw.TextSpan(text: 'Bill Type : '),
                        pw.TextSpan(text: data.billType, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ]),
                    ),
                  ],
                ),
              ),

              // Items — fully ruled table
              pw.Table(
                border: pw.TableBorder(
                  bottom: ruleDark,
                  horizontalInside: ruleLight,
                  verticalInside: ruleLight,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(0.5),
                  1: pw.FlexColumnWidth(0.9),
                  2: pw.FlexColumnWidth(3),
                  3: pw.FlexColumnWidth(0.8),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(0.8),
                  6: pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.1, color: PdfColors.grey900))),
                    children: [
                      _cell('SNo', bold: true),
                      _cell('HSCode', bold: true),
                      _cell('Particular', bold: true),
                      _cell('Qty', bold: true, align: pw.TextAlign.right),
                      _cell('Rate', bold: true, align: pw.TextAlign.right),
                      _cell('P.Disc', bold: true, align: pw.TextAlign.right),
                      _cell('Amount', bold: true, align: pw.TextAlign.right),
                    ],
                  ),
                  for (var i = 0; i < data.items.length; i++)
                    pw.TableRow(
                      children: [
                        _cell('${i + 1}'),
                        _cell(data.items[i].hsCode),
                        _cell(data.items[i].name, bold: true),
                        _cell(Formatters.amount(data.items[i].quantity), align: pw.TextAlign.right),
                        _cell(data.items[i].unitPrice.toStringAsFixed(2), align: pw.TextAlign.right),
                        _cell(data.items[i].discountAmount.toStringAsFixed(2), align: pw.TextAlign.right),
                        _cell(data.items[i].total.toStringAsFixed(2), align: pw.TextAlign.right, bold: true),
                      ],
                    ),
                  // A few ruled blank rows so a short bill still reads like a
                  // real invoice book instead of the table just stopping.
                  for (var i = 0; i < (data.items.length < 3 ? 3 - data.items.length : 0); i++)
                    pw.TableRow(children: [
                      _cell(' ', pad: 10), _cell(''), _cell(''), _cell(''), _cell(''), _cell(''), _cell(''),
                    ]),
                ],
              ),

              // Remarks/words + totals box
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(right: ruleDark, bottom: ruleDark),
                      ),
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (data.notes.isNotEmpty) ...[
                            pw.RichText(text: pw.TextSpan(style: pw.TextStyle(fontSize: 9, color: black), children: [
                              pw.TextSpan(text: 'Remarks : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.TextSpan(text: data.notes),
                            ])),
                            pw.SizedBox(height: 6),
                          ],
                          pw.RichText(text: pw.TextSpan(style: pw.TextStyle(fontSize: 9, color: black), children: [
                            pw.TextSpan(text: 'In Words : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.TextSpan(text: 'Rs. ${amountInWords(data.total)}'),
                          ])),
                          pw.SizedBox(height: 6),
                          pw.Text('*Proforma Invoice', style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: grey600)),
                        ],
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 190,
                    decoration: pw.BoxDecoration(border: pw.Border(bottom: ruleDark)),
                    child: pw.Table(
                      border: pw.TableBorder(horizontalInside: ruleLight),
                      children: [
                        _totalTableRow('Basic Amount', Formatters.currency(data.subtotal).replaceFirst('Rs. ', ''), black, bold: true),
                        _totalTableRow('Discount', data.discount.toStringAsFixed(2), black),
                        _totalTableRow('Taxable value', (data.subtotal - data.discount).toStringAsFixed(2), black, bold: true),
                        _totalTableRow('Vat ${Formatters.amount(data.taxRate)} %', data.taxAmount.toStringAsFixed(2), black),
                        _totalTableRow('Net Amount', data.total.toStringAsFixed(2), black, bold: true),
                        if (data.paidAmount > 0)
                          _totalTableRow('Received Amount', data.paidAmount.toStringAsFixed(2), black),
                        _totalTableRow(
                          data.dueAmount < 0 ? 'Advance (Overpaid)' : 'Amount Due',
                          data.dueAmount.abs().toStringAsFixed(2),
                          black, bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Signatures
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400))),
                padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _signatureLine('Received By'),
                    _signatureLine('Prepaid By'),
                    pw.Text('For : ${data.businessName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: black)),
                  ],
                ),
              ),

              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Print Date & Time : ${_now()}',
                    style: pw.TextStyle(fontSize: 7.5, color: grey600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return doc;
}

String _now() {
  final n = DateTime.now();
  final d = n.day.toString().padLeft(2, '0');
  final m = n.month.toString().padLeft(2, '0');
  final hour = n.hour % 12 == 0 ? 12 : n.hour % 12;
  final min = n.minute.toString().padLeft(2, '0');
  final ampm = n.hour >= 12 ? 'PM' : 'AM';
  return '$d/$m/${n.year} $hour:$min $ampm';
}

pw.Widget _kv(String label, String value, PdfColor color, {bool bold = false, bool alignEnd = false}) {
  if (value.isEmpty) return pw.SizedBox();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 1.5),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label : ', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
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

pw.TableRow _totalTableRow(String label, String value, PdfColor color, {bool bold = false}) {
  return pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: pw.Text(value, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ),
    ],
  );
}

pw.Widget _signatureLine(String label) {
  return pw.Column(
    children: [
      pw.Container(width: 100, height: 0.75, color: PdfColors.grey500),
      pw.SizedBox(height: 3),
      pw.Text(label, style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
    ],
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
