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
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double total;

  const BillPdfItem({
    required this.name,
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
  final String number;
  final String partyLabel; // 'Party' for a sale, 'Supplier' for a purchase
  final String partyName;
  final String partyPan;
  final String partyAddress;
  final String date;
  final String? miti; // BS date, already formatted
  final String? dueDate;
  final String paymentModeLabel;
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
    required this.number,
    required this.partyLabel,
    required this.partyName,
    this.partyPan = '',
    this.partyAddress = '',
    required this.date,
    this.miti,
    this.dueDate,
    this.paymentModeLabel = 'Cash',
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

/// Builds a one-page A4 PDF for [data] on a plain white page — independent
/// of the app's own light/dark theme, since this is a document the business
/// hands to a customer, not an in-app screen. Always carries a small
/// "*Proforma Invoice" note near the totals — permanent, not a per-print
/// choice (see printBillPdf/showBillPrintDialog, which no longer ask).
Future<pw.Document> buildBillPdf({
  required BillPdfData data,
  required String documentTitle,
}) async {
  final doc = pw.Document();
  final heading = documentTitle;
  final black = PdfColors.grey900;
  final grey = PdfColors.grey600;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Business header
            pw.Text(
              data.businessName,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: black),
            ),
            if (data.businessPhone.isNotEmpty || data.businessAddress.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  [data.businessPhone, data.businessAddress].where((s) => s.isNotEmpty).join('• '),
                  style: pw.TextStyle(fontSize: 9, color: grey),
                ),
              ),
            if (data.businessPan.isNotEmpty)
              pw.Text('PAN No: ${data.businessPan}', style: pw.TextStyle(fontSize: 9, color: grey)),
            pw.SizedBox(height: 16),

            pw.Center(
              child: pw.Text(
                heading.toUpperCase(),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: black),
              ),
            ),
            pw.SizedBox(height: 16),

            // Party + bill meta
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${data.partyLabel}:', style: pw.TextStyle(fontSize: 9, color: grey)),
                    pw.Text(data.partyName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: black)),
                    if (data.partyAddress.isNotEmpty)
                      pw.Text(data.partyAddress, style: pw.TextStyle(fontSize: 8, color: grey)),
                    if (data.partyPan.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text('PAN No: ${data.partyPan}', style: pw.TextStyle(fontSize: 8, color: grey)),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _metaRow('Bill No:', data.number, grey, black),
                    _metaRow('Date:', data.date, grey, black),
                    if (data.miti != null) _metaRow('Miti:', data.miti!, grey, black),
                    _metaRow('Payment Mode:', data.paymentModeLabel, grey, black),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            pw.Table(
              border: const pw.TableBorder(
                bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
                horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1.3),
                4: pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue700),
                  children: [
                    _cell('S.N.', bold: true, color: PdfColors.white),
                    _cell('Name', bold: true, color: PdfColors.white),
                    _cell('Qty', bold: true, align: pw.TextAlign.right, color: PdfColors.white),
                    _cell('Rate', bold: true, align: pw.TextAlign.right, color: PdfColors.white),
                    _cell('Amount', bold: true, align: pw.TextAlign.right, color: PdfColors.white),
                  ],
                ),
                for (var i = 0; i < data.items.length; i++)
                  pw.TableRow(
                    children: [
                      _cell('${i + 1}', color: grey),
                      _cell(data.items[i].name, bold: true, color: black),
                      _cell(Formatters.amount(data.items[i].quantity), align: pw.TextAlign.right),
                      _cell(Formatters.currency(data.items[i].unitPrice), align: pw.TextAlign.right),
                      _cell(Formatters.currency(data.items[i].total), align: pw.TextAlign.right, bold: true, color: black),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Amount in words + totals
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Amount in Words', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: black)),
                      pw.Text(amountInWords(data.total), style: pw.TextStyle(fontSize: 9, color: grey)),
                      pw.SizedBox(height: 8),
                      pw.Text('*Proforma Invoice', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: grey)),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 220,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _totalRow('Subtotal', Formatters.currency(data.subtotal), grey, black),
                      if (data.discount > 0)
                        _totalRow('Discount', '- ${Formatters.currency(data.discount)}', grey, black),
                      if (data.taxAmount > 0)
                        _totalRow('Tax (${Formatters.amount(data.taxRate)}%)', '+ ${Formatters.currency(data.taxAmount)}', grey, black),
                      _totalRow('Total Amount', Formatters.currency(data.total), black, black, bold: true),
                      _totalRow('Received Amount', Formatters.currency(data.paidAmount), grey, black),
                      pw.Divider(color: PdfColors.grey500, thickness: 1),
                      _totalRow(
                        data.dueAmount < 0 ? 'Advance (Overpaid)' : 'Amount Due',
                        Formatters.currency(data.dueAmount.abs()),
                        black, black, bold: true, big: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (data.notes.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Notes: ${data.notes}', style: pw.TextStyle(fontSize: 8, color: grey)),
            ],

            pw.SizedBox(height: 36),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 140,
                    height: 1,
                    color: PdfColors.grey400,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 8, color: grey)),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc;
}

pw.Widget _metaRow(String label, String value, PdfColor labelColor, PdfColor valueColor) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label ', style: pw.TextStyle(fontSize: 8, color: labelColor)),
          pw.TextSpan(text: value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: valueColor)),
        ],
      ),
    ),
  );
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  pw.TextAlign align = pw.TextAlign.left,
  PdfColor color = PdfColors.black,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );
}

pw.Widget _totalRow(
  String label,
  String value,
  PdfColor labelColor,
  PdfColor valueColor, {
  bool bold = false,
  bool big = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: big ? 13 : 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: labelColor,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: big ? 13 : 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
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
