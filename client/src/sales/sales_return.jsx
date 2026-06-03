import { useEffect, useMemo, useState } from "react";
import { createSalesReturn, getSales } from "../services/saleService";

export default function SalesReturn() {
  const [sales, setSales] = useState([]);
  const [saleId, setSaleId] = useState("");
  const [rows, setRows] = useState([]);
  const [dateAD, setDateAD] = useState(new Date().toISOString().slice(0, 10));
  const [dateBS, setDateBS] = useState("");
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

  const selected = useMemo(() => sales.find((x) => x._id === saleId), [sales, saleId]);

  useEffect(() => {
    if (!selected) {
      setRows([]);
      return;
    }

    setRows(
      (selected.items || []).map((item) => ({
        item: item.item,
        name: item.name,
        soldQty: Number(item.qty || 0),
        returnQty: 0,
      }))
    );
  }, [selected]);

  const updateQty = (i, value) => {
    setRows((prev) => {
      const copy = [...prev];
      copy[i] = { ...copy[i], returnQty: Number(value || 0) };
      return copy;
    });
  };

  const submit = async (e) => {
    e.preventDefault();

    const items = rows
      .filter((x) => Number(x.returnQty || 0) > 0)
      .map((x) => ({
        item: x.item,
        qty: Number(x.returnQty || 0),
      }));

    if (!saleId) return alert("Please select invoice");
    if (!items.length) return alert("Please enter return quantity");

    try {
      setSaving(true);
      await createSalesReturn(saleId, items, {
        returnDateAD: dateAD,
        returnDateBS: dateBS,
        note,
      });
      alert("Sales return created successfully");
      setSaleId("");
      setRows([]);
      setNote("");
      setDateAD(new Date().toISOString().slice(0, 10));
      setDateBS("");
    } catch (err) {
      alert(err?.response?.data?.message || "Failed to create sales return");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0b0d12] p-4 text-white md:p-6">
      <div className="mx-auto max-w-6xl rounded-2xl border border-slate-800 bg-[#101216] p-6">
        <h1 className="mb-6 text-3xl font-semibold">Sales Return</h1>

        <form onSubmit={submit} className="space-y-6">
          <div>
            <label className="mb-2 block text-sm font-medium text-slate-200">Select Sales Invoice</label>
            <select
              value={saleId}
              onChange={(e) => setSaleId(e.target.value)}
              className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
            >
              <option value="">Choose invoice</option>
              {sales.map((sale) => (
                <option key={sale._id} value={sale._id}>
                  {sale.invoiceNo} - {sale?.party?.name || sale?.partyName || "-"}
                </option>
              ))}
            </select>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-slate-200">Return Date (AD)</label>
              <input
                type="date"
                value={dateAD}
                onChange={(e) => setDateAD(e.target.value)}
                className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
              />
            </div>

            <div>
              <label className="mb-2 block text-sm font-medium text-slate-200">Return Date (BS)</label>
              <input
                value={dateBS}
                onChange={(e) => setDateBS(e.target.value)}
                placeholder="2082 Fal 10"
                className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
              />
            </div>
          </div>

          {rows.length > 0 ? (
            <div className="overflow-hidden rounded-2xl border border-slate-800">
              <div className="hidden grid-cols-4 bg-[#171a22] text-sm font-medium text-slate-300 md:grid">
                <div className="px-4 py-3">Item</div>
                <div className="px-4 py-3">Sold Qty</div>
                <div className="px-4 py-3">Return Qty</div>
                <div className="px-4 py-3">Remaining</div>
              </div>

              {rows.map((row, i) => (
                <div key={i} className="grid grid-cols-1 gap-3 border-t border-slate-800 bg-[#0f1218] p-4 md:grid-cols-4 md:gap-0 md:p-0">
                  <div className="px-4 py-3">{row.name}</div>
                  <div className="px-4 py-3">{row.soldQty}</div>
                  <div className="px-4 py-2">
                    <input
                      type="number"
                      min="0"
                      max={row.soldQty}
                      value={row.returnQty}
                      onChange={(e) => updateQty(i, e.target.value)}
                      className="h-11 w-full rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
                    />
                  </div>
                  <div className="px-4 py-3">{Math.max(0, row.soldQty - row.returnQty)}</div>
                </div>
              ))}
            </div>
          ) : null}

          <div>
            <label className="mb-2 block text-sm font-medium text-slate-200">Note</label>
            <textarea
              rows={4}
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
            {saving ? "Saving..." : "Save Sales Return"}
          </button>
        </form>
      </div>
    </div>
  );
}