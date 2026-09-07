import { amountInWords } from "../../utils/amountInWords";

/* Solid accent-colored band with a curved white wedge cut out of the top
   right corner — the header's "flowing wave" shape. preserveAspectRatio
   ="none" lets it stretch to whatever header size the caller renders at
   without distorting the curve's proportions relative to itself. */
function HeaderCurve({ color }) {
  // viewBox matches the header's real ~6:1 width:height ratio (max-w-3xl
  // card, h-32 tall) so the wedge's curve isn't stretched into a different
  // shape than drawn — a squarer viewBox here previously let the white
  // wedge balloon sideways under non-uniform scaling and clip into the
  // document title text.
  return (
    <svg className="absolute inset-0 h-full w-full" viewBox="0 0 760 130" preserveAspectRatio="none" aria-hidden="true">
      <rect width="760" height="130" fill={color} />
      <path d="M380,0 C500,8 640,50 760,92 L760,0 Z" fill="white" />
    </svg>
  );
}

/* Thin decorative wave hugging the bottom edge of the page, echoing the
   header's curve so the sheet reads as one designed piece. */
function FooterCurve({ color }) {
  return (
    <svg className="absolute inset-x-0 bottom-0 h-full w-full" viewBox="0 0 760 40" preserveAspectRatio="none" aria-hidden="true">
      <path d="M0,40 L0,20 C210,2 490,36 760,12 L760,40 Z" fill={color} />
    </svg>
  );
}

/* Stylized signature squiggle — decorative only, not a real signature —
   sitting above "Authorized Signature" the way a hand-signed bill would. */
function SignatureMark({ color }) {
  return (
    <svg width="110" height="40" viewBox="0 0 110 40" fill="none" aria-hidden="true">
      <path
        d="M4 30 C 14 8, 22 8, 26 24 C 29 34, 36 20, 42 15 C 48 10, 51 27, 58 19 C 66 9, 71 27, 80 17 C 88 9, 93 22, 106 11"
        stroke={color} strokeWidth="2" strokeLinecap="round" fill="none"
      />
    </svg>
  );
}

/**
 * Shared "paper" content for every printed bill (Sales invoice, Purchase
 * bill, Quotation) — a curved, accent-colored header/footer around a plain
 * white body, so all three read as one consistent design instead of each
 * page hand-rolling its own layout. Callers translate their own field names
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
  const footerCols = [
    paymentMethodLabel && { label: "Payment Method", value: paymentMethodLabel },
    termsText && { label: "Terms & Conditions", value: termsText },
    warrantyText && { label: "Warranty", value: warrantyText },
  ].filter(Boolean);

  return (
    // bg-[#ffffff]/text-[#ffffff] (not bg-white/text-white) deliberately —
    // this app's light theme remaps the "white" token to deep navy (see
    // index.css), so a printed bill must bypass that token entirely to
    // stay actual white paper with actual white header text.
    <div className="overflow-hidden rounded-2xl bg-[#ffffff] text-gray-800" id="print-area">
      {/* Header */}
      <div className="relative h-32 overflow-hidden print:h-28">
        <HeaderCurve color={accentColor} />
        <div className="relative z-10 flex h-full items-start justify-between p-6">
          <div className="max-w-[62%] text-[#ffffff]">
            {business?.logo && (
              <img src={business.logo} alt="" className="mb-1.5 h-8 w-8 rounded bg-[#ffffff]/90 object-contain p-0.5" />
            )}
            <p className="text-lg font-bold leading-tight">{business?.name || "Your Business"}</p>
            {business?.address && <p className="mt-0.5 text-[11px] opacity-90">{business.address}</p>}
            {(business?.phone || business?.email) && (
              <p className="text-[11px] opacity-90">{[business?.phone, business?.email].filter(Boolean).join("   ")}</p>
            )}
            {(business?.pan || business?.vat) && (
              <p className="text-[11px] opacity-90">
                {business?.pan && `PAN: ${business.pan}`}
                {business?.pan && business?.vat && "   "}
                {business?.vat && `VAT: ${business.vat}`}
              </p>
            )}
          </div>
          <p className="pt-1 text-3xl font-extrabold tracking-tight" style={{ color: accentColor }}>{documentLabel}</p>
        </div>
      </div>

      {/* Bill-to / document meta */}
      <div className="flex flex-wrap items-start justify-between gap-4 px-6 pt-5 text-xs">
        <div>
          <p className="mb-1 text-[10px] font-bold uppercase tracking-wide text-gray-400">{billToLabel}</p>
          <p className="font-semibold text-gray-900">{billTo?.name || "—"}</p>
          {billTo?.address && <p className="text-gray-500">{billTo.address}</p>}
          {billTo?.phone && <p className="text-gray-500">{billTo.phone}</p>}
          {billTo?.email && <p className="text-gray-500">{billTo.email}</p>}
        </div>
        <div className="space-y-0.5 text-right">
          <p><span className="font-semibold text-gray-500">{documentNumberLabel}</span>{" "}<span className="font-bold text-gray-900">{documentNumber}</span></p>
          {date && <p><span className="font-semibold text-gray-500">{dateLabel}</span>{" "}<span className="text-gray-900">{date}</span></p>}
          {dueDate && <p><span className="font-semibold text-gray-500">{dueLabel}</span>{" "}<span className="text-gray-900">{dueDate}</span></p>}
        </div>
      </div>

      {/* Items */}
      {hasItems && (
        <div className="mt-4 overflow-x-auto px-6 print:overflow-visible">
          <table className="w-full min-w-[480px] border-collapse text-xs">
            <thead>
              <tr style={{ backgroundColor: accentColor }} className="text-left text-[#ffffff]">
                <th className="rounded-l-lg px-3 py-2 font-semibold">Description</th>
                <th className="px-3 py-2 text-right font-semibold">Quantity</th>
                <th className="px-3 py-2 text-right font-semibold">Price</th>
                <th className="px-3 py-2 text-right font-semibold">Discount</th>
                <th className="px-3 py-2 text-right font-semibold">Tax</th>
                <th className="rounded-r-lg px-3 py-2 text-right font-semibold">Amount</th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => (
                <tr key={i} className="border-b border-gray-100">
                  <td className="px-3 py-2 font-medium text-gray-800">{it.description}</td>
                  <td className="px-3 py-2 text-right">{it.quantity}</td>
                  <td className="px-3 py-2 text-right">{it.price}</td>
                  <td className="px-3 py-2 text-right">{it.discount || "--"}</td>
                  <td className="px-3 py-2 text-right">{it.taxLabel || "--"}</td>
                  <td className="px-3 py-2 text-right font-semibold text-gray-900">{it.amount}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Notes + totals */}
      <div className="flex flex-wrap items-start justify-between gap-6 px-6 py-5">
        <div className="max-w-[50%] text-xs text-gray-500">
          {notes && <p><span className="font-semibold text-gray-700">Notes: </span>{notes}</p>}
          {totals?.total != null && <p className="mt-1 italic">In words: {amountInWords(totals.total)}</p>}
        </div>
        <div className="min-w-[220px] flex-1 max-w-xs space-y-1.5 text-xs">
          <div className="flex justify-between">
            <span className="text-gray-500">Subtotal</span>
            <span className="font-medium text-gray-800">{totals?.subtotal}</span>
          </div>
          {!!totals?.discount && (
            <div className="flex justify-between">
              <span className="text-gray-500">Total Discount</span>
              <span className="font-medium text-red-500">-{totals.discount}</span>
            </div>
          )}
          {!!totals?.taxAmount && (
            <div className="flex justify-between">
              <span className="text-gray-500">{totals?.taxLabel || "Tax"}</span>
              <span className="font-medium text-gray-800">{totals.taxAmount}</span>
            </div>
          )}
          <div
            className="mt-1 flex items-center justify-between rounded-lg px-3 py-2 text-sm font-bold"
            style={{ backgroundColor: `${accentColor}1a`, color: accentColor }}
          >
            <span>Total</span><span>{totals?.total}</span>
          </div>
          {!!totals?.paidAmount && (
            <div className="flex justify-between pt-1">
              <span className="text-gray-500">Received</span>
              <span className="font-medium text-gray-800">{totals.paidAmount}</span>
            </div>
          )}
          {totals?.dueAmount != null && (
            <div className="flex justify-between">
              <span className="text-gray-500">{totals.isAdvance ? "Advance (Overpaid)" : "Amount Due"}</span>
              <span className="font-semibold text-gray-900">{totals.dueAmount}</span>
            </div>
          )}
        </div>
      </div>

      {/* Footer */}
      <div className="relative overflow-hidden px-6 pb-8 pt-6 print:pb-5">
        {footerCols.length > 0 && (
          <div className="relative z-10 mb-8 flex flex-wrap gap-8 text-xs print:mb-6">
            {footerCols.map((col) => (
              <div key={col.label}>
                <p className="font-bold text-gray-900">{col.label}</p>
                <p className="text-gray-500">{col.value}</p>
              </div>
            ))}
          </div>
        )}
        <div className="relative z-10 flex justify-end">
          <div className="text-center">
            <SignatureMark color={accentColor} />
            <p className="mt-0.5 text-[10px] text-gray-500">Authorized Signature</p>
          </div>
        </div>
        {footerNote && (
          <p className="relative z-10 mt-4 text-center text-[10px] italic text-gray-400">{footerNote}</p>
        )}
        <div className="absolute inset-x-0 bottom-0 h-9 opacity-90">
          <FooterCurve color={accentColor} />
        </div>
      </div>
    </div>
  );
}
