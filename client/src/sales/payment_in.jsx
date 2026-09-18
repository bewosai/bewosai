import { useEffect, useMemo, useState } from "react";
import { addPaymentIn, getSales } from "../services/saleService";
import { todayStr } from "../utils/dates";

const money = (n) =>
  `Rs. ${Number(n || 0).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;

export default function PaymentIn() {
  const [sales, setSales] = useState([]);
  const [saleId, setSaleId] = useState("");
  const [amount, setAmount] = useState("");
  const [paymentDateAD, setPaymentDateAD] = useState(todayStr());
  const [paymentDateBS, setPaymentDateBS] = useState("");
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);

  const loadSales = async () => {
    try {
      const res = await getSales("sale");
      setSales(res?.sales || []);
    } catch (err) {
      alert(err?.response?.data?.message || "Failed to load sales");
    }
  };

  useEffect(() => {
    loadSales();
  }, []);

  const selectedSale = useMemo(
    () => sales.find((x) => x._id === saleId),
    [sales, saleId]
  );

  const savePayment = async (e) => {
    e.preventDefault();

    if (!saleId) return alert("Please select invoice");
    if (Number(amount || 0) <= 0) return alert("Enter valid payment amount");

    try {
      setSaving(true);
      await addPaymentIn(saleId, Number(amount || 0), {
        paymentDateAD,
        paymentDateBS,
        note,
      });
      alert("Payment saved successfully");
      setAmount("");
      setNote("");
      setSaleId("");
      loadSales();
    } catch (err) {
      alert(err?.response?.data?.message || "Failed to save payment");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0b0d12] p-4 text-white md:p-6">
      <div className="mx-auto max-w-4xl rounded-2xl border border-slate-800 bg-[#101216] p-6">
        <h1 className="mb-6 text-3xl font-semibold">Payment In</h1>

        <form onSubmit={savePayment} className="space-y-5">
          <div>
            <label className="mb-2 block text-sm font-medium text-slate-200">Select Invoice</label>
            <select
              value={saleId}
              onChange={(e) => setSaleId(e.target.value)}
              className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
            >
              <option value="">Choose invoice</option>
              {sales.map((sale) => (
                <option key={sale._id} value={sale._id}>
                  {sale.invoiceNo} - {sale?.party?.name || sale?.partyName || "-"} - Due {money(sale?.totals?.due)}
                </option>
              ))}
            </select>
          </div>

          {selectedSale ? (
            <div className="grid gap-4 rounded-2xl border border-slate-800 bg-[#0d1015] p-4 md:grid-cols-2">
              <div>Invoice No: <span className="font-semibold">{selectedSale.invoiceNo}</span></div>
              <div>Party: <span className="font-semibold">{selectedSale?.party?.name || selectedSale?.partyName || "-"}</span></div>
              <div>Total: <span className="font-semibold">{money(selectedSale?.totals?.grandTotal)}</span></div>
              <div>Due: <span className="font-semibold text-yellow-300">{money(selectedSale?.totals?.due)}</span></div>
            </div>
          ) : null}

          <div className="grid gap-4 md:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-slate-200">Payment Date (AD)</label>
              <input
                type="date"
                value={paymentDateAD}
                onChange={(e) => setPaymentDateAD(e.target.value)}
                className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
              />
            </div>

            <div>
              <label className="mb-2 block text-sm font-medium text-slate-200">Payment Date (BS)</label>
              <input
                placeholder="2082 Fal 10"
                value={paymentDateBS}
                onChange={(e) => setPaymentDateBS(e.target.value)}
                className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
              />
            </div>
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-slate-200">Amount</label>
            <input
              type="number"
              min="0"
              placeholder="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
            />
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-slate-200">Note</label>
            <textarea
              rows={4}
              placeholder="Payment note"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 py-3 outline-none focus:border-emerald-500"
            />
          </div>

          <button
            type="submit"
            disabled={saving}
            className="rounded-2xl bg-emerald-500 px-6 py-3 font-semibold hover:bg-emerald-600 disabled:opacity-60"
          >
            {saving ? "Saving..." : "Save Payment"}
          </button>
        </form>
      </div>
    </div>
  );
}