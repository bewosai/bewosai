import { useEffect, useMemo, useState } from "react";
import { deleteSale, getSales } from "../services/saleService";

const money = (n) =>
  `Rs. ${Number(n || 0).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })}`;

function statusBadge(due) {
  if (Number(due || 0) > 0) {
    return (
      <span className="rounded-md bg-red-500/15 px-3 py-1 text-xs font-semibold text-red-400">
        UNPAID
      </span>
    );
  }
  return (
    <span className="rounded-md bg-emerald-500/15 px-3 py-1 text-xs font-semibold text-emerald-400">
      PAID
    </span>
  );
}

export default function SalesInvoice() {
  const [sales, setSales] = useState([]);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [loading, setLoading] = useState(true);

  const loadSales = async () => {
    try {
      setLoading(true);
      const res = await getSales("sale");
      setSales(res?.sales || []);
    } catch (err) {
      console.error(err);
      alert(err?.response?.data?.message || "Failed to load sales");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSales();
  }, []);

  const filtered = useMemo(() => {
    return sales.filter((sale) => {
      const q = search.toLowerCase();
      const matchSearch =
        String(sale?.invoiceNo || "").toLowerCase().includes(q) ||
        String(sale?.party?.name || sale?.partyName || "").toLowerCase().includes(q);

      const due = Number(sale?.totals?.due || 0);
      const matchStatus =
        status === "all" ||
        (status === "paid" && due <= 0) ||
        (status === "unpaid" && due > 0);

      return matchSearch && matchStatus;
    });
  }, [sales, search, status]);

  const onDelete = async (id) => {
    const ok = window.confirm("Move this invoice to recycle bin?");
    if (!ok) return;

    try {
      await deleteSale(id);
      loadSales();
    } catch (err) {
      alert(err?.response?.data?.message || "Failed to delete invoice");
    }
  };

  return (
    <div className="min-h-screen bg-[#0b0d12] p-4 text-white md:p-6">
      <div className="mx-auto max-w-7xl rounded-2xl border border-slate-800 bg-[#101216] p-6">
        <div className="mb-6 flex flex-col items-start justify-between gap-4 md:flex-row md:items-center">
          <div>
            <h1 className="text-3xl font-semibold">Sales Invoices ({filtered.length})</h1>
          </div>

          <button className="rounded-2xl bg-emerald-500 px-5 py-3 font-semibold hover:bg-emerald-600">
            + Create Sales Invoice
          </button>
        </div>

        <div className="mb-4 grid gap-3 md:grid-cols-4">
          <input
            placeholder="Search invoices..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="h-11 rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500 md:col-span-2"
          />

          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className="h-11 rounded-xl border border-slate-700 bg-[#0d1015] px-4 outline-none focus:border-emerald-500"
          >
            <option value="all">All Status</option>
            <option value="paid">Paid</option>
            <option value="unpaid">Unpaid</option>
          </select>

          <button className="h-11 rounded-xl border border-slate-700 bg-[#0d1015] px-4 hover:border-emerald-500">
            Sort By
          </button>
        </div>

        <div className="overflow-hidden rounded-2xl border border-slate-800">
          <div className="hidden grid-cols-7 bg-[#171a22] text-sm font-medium text-slate-300 md:grid">
            <div className="px-4 py-3">Invoice No</div>
            <div className="px-4 py-3">Party Name</div>
            <div className="px-4 py-3">Date</div>
            <div className="px-4 py-3">Status</div>
            <div className="px-4 py-3">Total Amount</div>
            <div className="px-4 py-3">Unpaid Amount</div>
            <div className="px-4 py-3">Action</div>
          </div>

          {loading ? (
            <div className="p-6 text-slate-400">Loading invoices...</div>
          ) : filtered.length === 0 ? (
            <div className="p-6 text-slate-400">No sales invoices found.</div>
          ) : (
            filtered.map((sale) => (
              <div
                key={sale._id}
                className="grid grid-cols-1 gap-3 border-t border-slate-800 bg-[#0f1218] p-4 md:grid-cols-7 md:gap-0 md:p-0"
              >
                <div className="px-4 py-3 font-semibold">{sale.invoiceNo}</div>
                <div className="px-4 py-3">{sale?.party?.name || sale?.partyName || "-"}</div>
                <div className="px-4 py-3">{sale?.invoiceDateBS || sale?.invoiceDateAD || sale?.invoiceDate || "-"}</div>
                <div className="px-4 py-3">{statusBadge(sale?.totals?.due)}</div>
                <div className="px-4 py-3 font-semibold">{money(sale?.totals?.grandTotal)}</div>
                <div className="px-4 py-3 font-semibold text-white">
                  {Number(sale?.totals?.due || 0) > 0 ? money(sale?.totals?.due) : "--"}
                </div>
                <div className="flex items-center gap-2 px-4 py-3">
                  <button className="rounded-lg px-3 py-2 text-slate-300 hover:bg-slate-800">📄</button>
                  <button
                    onClick={() => onDelete(sale._id)}
                    className="rounded-lg px-3 py-2 text-slate-300 hover:bg-slate-800"
                  >
                    ⋮
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}