import { amountInWords } from "../../utils/amountInWords";

/**
 * Shared "paper" content for every printed bill (Sales invoice, Purchase
 * bill, Quotation) — a solid accent-colored header/footer bar around a
 * plain white body, a boxed Amount in Words + totals block, and boxed
 * Terms & Conditions / Seal and Signature panels, mirroring the classic
 * printable-invoice layout (matches the mobile app's PDF, see
 * app/lib/shared/pdf/bill_pdf.dart) that Nepali small businesses already
 * expect a bill to look like. Callers translate their own field names
 * (sale.*, purchase.*, quotation.*) into these generic props; this
 * component doesn't know which document type it's rendering.
 *
 * `accentColor` should be the business's Settings > Invoice Customization
 * > Header Color (localStorage "invoice_header_color") — the one place
 * that color is meant to apply.
 */
export default function BillTemplate({
  accentColor = "#f97316",
  documentLabel = "Invoice",
  documentNumberLabel = "Invoice No.",
  documentNumber,
  dateLabel = "Date",
  date,
  dueLabel,
  dueDate,
  business,
  billToLabel = "Bill To",
  billTo,
  items,
  notes,
  totals,
  paymentMethodLabel,
  termsText,
  warrantyText,
  footerNote,
}) {
  const hasItems = Array.isArray(items) && items.length > 0;
  const rows = hasItems ? items : [];
  const padRows = Math.max(0, 3 - rows.length);
  const metaRows = [
    { label: dateLabel, value: date },
    { label: documentNumberLabel, value: documentNumber, bold: true },
    dueDate && { label: dueLabel, value: dueDate },
    paymentMethodLabel && { label: "Payment Mode", value: paymentMethodLabel },
  ].filter(Boolean);

  return (
    // bg-[#ffffff]/text-[#ffffff] (not bg-white/text-white) deliberately —
    // this app's light theme remaps the "white" token to deep navy (see
    // index.css), so a printed bill must bypass that token entirely to
    // stay actual white paper with actual white header text.
    <div className="overflow-hidden bg-[#ffffff] text-gray-800" id="print-area">
      {/* Header bar */}
      <div className="flex items-center justify-between px-6 py-4" style={{ backgroundColor: accentColor }}>
        <div className="flex items-center gap-2 text-[#ffffff]">
          {business?.logo && (
            <img src={business.logo} alt="" className="h-8 w-8 rounded bg-[#ffffff]/90 object-contain p-0.5" />
          )}
          <p className="text-lg font-bold leading-tight">{business?.name || "Your Business"}</p>
        </div>
        <p className="text-sm font-bold uppercase tracking-wide text-[#ffffff]">{documentLabel}</p>
      </div>

      {/* Company address / contact — colored text under the bar, echoing a
          printed letterhead. */}
      {(business?.address || business?.phone || business?.email || business?.pan || business?.vat) && (
        <div className="px-6 pt-3 text-[11px] leading-5" style={{ color: accentColor }}>
          {business?.address && <p><span className="font-bold">Company Address: </span>{business.address}</p>}
          {(business?.phone || business?.email) && (
            <p><span className="font-bold">Contact Details: </span>{[business?.phone, business?.email].filter(Boolean).join("   ")}</p>
          )}
          {(business?.pan || business?.vat) && (
            <p>
              <span className="font-bold">PAN / VAT: </span>
              {[business?.pan, business?.vat].filter(Boolean).join("   ")}
            </p>
          )}
        </div>
      )}

      <div className="mx-6 mt-3 border-t border-gray-200" />

      {/* Bill-to / document meta */}
      <div className="flex flex-wrap items-start justify-between gap-4 px-6 pt-4 text-xs">
        <div>
          <p className="mb-1 text-[10px] font-bold uppercase tracking-wide" style={{ color: accentColor }}>{billToLabel}</p>
          <p className="font-semibold text-gray-900">{billTo?.name || "—"}</p>
          {billTo?.address && <p className="text-gray-500">{billTo.address}</p>}
          {billTo?.phone && <p className="text-gray-500">{billTo.phone}</p>}
          {billTo?.email && <p className="text-gray-500">{billTo.email}</p>}
        </div>
        <div className="space-y-0.5 text-right">
          {metaRows.map((m) => (
            <p key={m.label}>
              <span className="font-semibold text-gray-500">{m.label}: </span>
              <span className={m.bold ? "font-bold text-gray-900" : "text-gray-900"}>{m.value}</span>
            </p>
          ))}
        </div>
      </div>

      {/* Items */}
      <div className="mt-4 overflow-x-auto px-6 print:overflow-visible">
        <table className="w-full min-w-[520px] border-collapse text-xs">
          <thead>
            <tr style={{ backgroundColor: accentColor }} className="text-left text-[#ffffff]">
              <th className="px-3 py-2 font-semibold">SL NO</th>
              <th className="px-3 py-2 font-semibold">ITEM</th>
              <th className="px-3 py-2 text-right font-semibold">QUANTITY</th>
              <th className="px-3 py-2 text-right font-semibold">PRICE/UNIT</th>
              <th className="px-3 py-2 text-right font-semibold">TAX RATE</th>
              <th className="px-3 py-2 text-right font-semibold">TOTAL</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((it, i) => (
              <tr key={i} className={i % 2 === 1 ? "bg-gray-50" : undefined}>
                <td className="px-3 py-2 text-gray-500">{i + 1}</td>
                <td className="px-3 py-2 font-medium text-gray-800">{it.description}</td>
                <td className="px-3 py-2 text-right">{it.quantity}</td>
                <td className="px-3 py-2 text-right">{it.price}</td>
                <td className="px-3 py-2 text-right">{it.taxLabel || "--"}</td>
                <td className="px-3 py-2 text-right font-semibold text-gray-900">{it.amount}</td>
              </tr>
            ))}
            {Array.from({ length: padRows }).map((_, i) => (
              <tr key={`pad-${i}`} className={(rows.length + i) % 2 === 1 ? "bg-gray-50" : undefined}>
                <td className="px-3 py-3" colSpan={6}>&nbsp;</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="mx-6 border-t border-gray-200" />

      {/* Amount in words (boxed) + totals */}
      <div className="flex flex-wrap items-stretch gap-4 px-6 py-5">
        <div className="min-w-[240px] flex-1 rounded-lg border border-gray-200 p-3 text-xs text-gray-600">
          <p className="text-[10px] font-bold uppercase tracking-wide" style={{ color: accentColor }}>Amount in Words</p>
          {totals?.total != null && <p className="mt-1">Rs. {amountInWords(totals.total)}</p>}
          {notes && <p className="mt-2"><span className="font-semibold text-gray-700">Remarks: </span>{notes}</p>}
        </div>
        <div className="min-w-[220px] max-w-xs flex-1 space-y-1.5 text-xs">
          <div className="flex justify-between border-b border-gray-200 pb-1.5">
            <span className="text-gray-500">Subtotal</span>
            <span className="font-medium text-gray-800">{totals?.subtotal}</span>
          </div>
          {!!totals?.discount && (
            <div className="flex justify-between border-b border-gray-200 pb-1.5">
              <span className="text-gray-500">Discount</span>
              <span className="font-medium text-red-500">-{totals.discount}</span>
            </div>
          )}
          {!!totals?.taxAmount && (
            <div className="flex justify-between border-b border-gray-200 pb-1.5">
              <span className="text-gray-500">{totals?.taxLabel || "Tax"}</span>
              <span className="font-medium text-gray-800">{totals.taxAmount}</span>
            </div>
          )}
          <div
            className="flex items-center justify-between rounded-lg px-3 py-2 text-sm font-bold text-[#ffffff]"
            style={{ backgroundColor: accentColor }}
          >
            <span>Total</span><span>{totals?.total}</span>
          </div>
          {!!totals?.paidAmount && (
            <div className="flex justify-between pt-1">
              <span className="text-gray-500">Paid</span>
              <span className="font-medium text-gray-800">{totals.paidAmount}</span>
            </div>
          )}
          {totals?.dueAmount != null && (
            <div className="flex justify-between">
              <span className="text-gray-500">{totals.isAdvance ? "Advance (Overpaid)" : "Due"}</span>
              <span className="font-semibold text-gray-900">{totals.dueAmount}</span>
            </div>
          )}
        </div>
      </div>

      {/* Terms & Conditions (boxed) + Seal and Signature (boxed) */}
      <div className="flex flex-wrap items-stretch gap-4 px-6 pb-6 text-xs">
        <div className="min-h-[90px] min-w-[240px] flex-1 rounded-lg border border-gray-200 p-3">
          <p className="font-bold text-gray-900">Terms and Conditions</p>
          <p className="mt-1 text-gray-500">
            {termsText || "Goods once sold will not be taken back or exchanged. All disputes are subject to local jurisdiction only."}
          </p>
          {warrantyText && <p className="mt-2"><span className="font-semibold text-gray-700">Warranty: </span>{warrantyText}</p>}
        </div>
        <div className="flex min-h-[90px] min-w-[220px] max-w-xs flex-1 items-end justify-center rounded-lg border border-gray-200 p-3">
          <p className="font-bold text-gray-900">Seal and Signature</p>
        </div>
      </div>

      {/* Thank-you + footer bar */}
      <p className="px-6 pb-3 text-center text-xs font-bold text-gray-900">
        THANKS FOR DOING BUSINESS WITH US. PLEASE VISIT US AGAIN !!!
      </p>
      {footerNote && <p className="px-6 pb-3 text-center text-[10px] italic text-gray-400">{footerNote}</p>}
      <div className="flex justify-end px-6 py-2 text-[10px] text-[#ffffff]" style={{ backgroundColor: accentColor }}>
        Powered by Bewosai
      </div>
    </div>
  );
}
