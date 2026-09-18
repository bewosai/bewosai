import { useMemo, useState } from "react";
import { createSale } from "../services/saleService";
import { todayStr } from "../utils/dates";

const money = (n) =>
  `Rs. ${Number(n || 0).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;

const makeRow = () => ({
  item: "",
  name: "",
  qty: 1,
  price: "",
  discountPercent: "",
});

function calc(row) {
  const qty = Number(row.qty || 0);
  const price = Number(row.price || 0);
  const discountPercent = Number(row.discountPercent || 0);

  const base = qty * price;
  const discount = (base * discountPercent) / 100;
  const total = Math.max(0, base - discount);

  return { base, discount, total };
}

export default function Quotation() {
  const [partyName, setPartyName] = useState("");
  const [invoiceNo, setInvoiceNo] = useState("");
  const [dateAD, setDateAD] = useState(todayStr());
  const [dateBS, setDateBS] = useState("");
  const [note, setNote] = useState("");
  const [items, setItems] = useState([makeRow()]);
  const [saving, setSaving] = useState(false);

  const lines = useMemo(() => items.map(calc), [items]);
  const total = lines.reduce((s, x) => s + x.total, 0);

  const updateRow = (i, field, value) => {
    setItems((prev) => {
      const copy = [...prev];
      copy[i] = { ...copy[i], [field]: value };
      return copy;
    });
  };

  const addRow = () => setItems((prev) => [...prev, makeRow()]);
  const removeRow = (i) => setItems((prev) => (prev.length === 1 ? prev : prev.filter((_, x) => x !== i)));

  const submit = async (e) => {
    e.preventDefault();

    try {
      setSaving(true);
      await createSale({
        partyName,
        invoiceNo,
        invoiceDate: dateAD,
        invoiceDateAD: dateAD,
        invoiceDateBS: dateBS,
        note,
        paid: 0,
        status: "quotation",
        items: items.map((row) => ({
          item: row.item || row.name,
          name: row.name,
          qty: Number(row.qty || 0),
          price: Number(row.price || 0),
          discountPercent: Number(row.discountPercent || 0),
          discount: (Number(row.qty || 0) * Number(row.price || 0) * Number(row.discountPercent || 0)) / 100,
          taxRate: 0,
        })),
      });

      alert("Quotation saved successfully");
      setPartyName("");
      setInvoiceNo("");
      setDateAD(todayStr());
      setDateBS("");
      setNote("");
      setItems([makeRow()]);
    } catch (err) {
      alert(err?.response?.data?.message || "Failed to save quotation");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0b0d12] p-4 text-white md:p-6">
      <div className="mx-auto max-w-7xl rounded-2xl border border-slate-800 bg-[#101216] p-6">
        <h1 className="mb-6 text-3xl font-semibold">Create Quotation</h1>

        <form onSubmit={submit}>
          <div className="mb-6 grid gap-4 lg:grid-cols-12">
            <div className="lg:col-span-5">
              <label className="mb-2 block text-sm font-medium text-slate-200">Party Name</label>
              <input
                value={partyName}
                onChange={(e) => setPartyName(e.target.value)}
                placeholder="Search or enter party"
                className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
              />
            </div>

            <div className="lg:col-span-2 lg:col-start-9">
              <label className="mb-2 block text-sm font-medium text-slate-200">Quotation No</label>
              <input
                value={invoiceNo}
                onChange={(e) => setInvoiceNo(e.target.value)}
                className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
              />
            </div>

            <div className="lg:col-span-2">
              <label className="mb-2 block text-sm font-medium text-slate-200">Date (AD)</label>
              <input
                type="date"
                value={dateAD}
                onChange={(e) => setDateAD(e.target.value)}
                className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
              />
            </div>

            <div className="lg:col-span-3">
              <label className="mb-2 block text-sm font-medium text-slate-200">Date (BS)</label>
              <input
                value={dateBS}
                onChange={(e) => setDateBS(e.target.value)}
                placeholder="2082 Fal 10"
                className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
              />
            </div>
          </div>

          <div className="overflow-hidden rounded-2xl border border-slate-800">
            <div className="hidden grid-cols-6 bg-[#171a22] text-sm font-medium text-slate-300 md:grid">
              <div className="px-4 py-3">Name</div>
              <div className="px-4 py-3">Qty</div>
              <div className="px-4 py-3">Rate</div>
              <div className="px-4 py-3">Discount %</div>
              <div className="px-4 py-3">Amount</div>
              <div className="px-4 py-3">Action</div>
            </div>

            {items.map((row, i) => (
              <div key={i} className="grid grid-cols-1 gap-3 border-t border-slate-800 bg-[#0f1218] p-4 md:grid-cols-6 md:gap-0 md:p-0">
                <div className="px-4 py-2">
                  <input
                    value={row.name}
                    onChange={(e) => updateRow(i, "name", e.target.value)}
                    placeholder="Enter item name"
                    className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
                  />
                </div>
                <div className="px-4 py-2">
                  <input
                    type="number"
                    value={row.qty}
                    onChange={(e) => updateRow(i, "qty", e.target.value)}
                    className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
                  />
                </div>
                <div className="px-4 py-2">
                  <input
                    type="number"
                    value={row.price}
                    onChange={(e) => updateRow(i, "price", e.target.value)}
                    className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
                  />
                </div>
                <div className="px-4 py-2">
                  <input
                    type="number"
                    value={row.discountPercent}
                    onChange={(e) => updateRow(i, "discountPercent", e.target.value)}
                    className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
                  />
                </div>
                <div className="px-4 py-3 font-semibold text-emerald-400">{money(lines[i]?.total)}</div>
                <div className="px-4 py-2">
                  <button
                    type="button"
                    onClick={() => removeRow(i)}
                    className="rounded-xl px-3 py-2 text-red-400 hover:bg-red-500/10"
                  >
                    Remove
                  </button>
                </div>
              </div>
            ))}

            <div className="px-4 py-3">
              <button type="button" onClick={addRow} className="text-emerald-400 hover:text-emerald-300">
                + Add Billing Item
              </button>
            </div>
          </div>

          <div className="mt-6 grid gap-6 lg:grid-cols-12">
            <div className="lg:col-span-7">
              <label className="mb-2 block text-sm font-medium text-slate-200">Notes or Remarks</label>
              <textarea
                rows={4}
                value={note}
                onChange={(e) => setNote(e.target.value)}
                className="w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 py-3 outline-none focus:border-emerald-500"
              />
            </div>

            <div className="lg:col-span-5 space-y-4">
              <div className="grid grid-cols-2 items-center gap-4">
                <div className="text-2xl font-semibold">Quotation Amount</div>
                <input
                  readOnly
                  value={money(total)}
                  className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 text-emerald-400 outline-none"
                />
              </div>
            </div>
          </div>

          <div className="mt-8 flex justify-end">
            <button
              type="submit"
              disabled={saving}
              className="rounded-2xl bg-emerald-500 px-6 py-3 font-semibold hover:bg-emerald-600 disabled:opacity-60"
            >
              {saving ? "Saving..." : "Save Quotation"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}