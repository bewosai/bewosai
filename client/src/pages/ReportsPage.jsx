import { useState, useEffect } from "react";
import { Printer, TrendingUp, TrendingDown, DollarSign, Package, Download, FileText, Calendar } from "lucide-react";
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Legend,
} from "recharts";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import { reports as reportsApi, sales as salesApi, expenses as expensesApi, purchases as purchasesApi } from "../api/index.js";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/* ── CSV export helper ── */
function exportCSV(headers, rows, filename) {
  const escape = (v) => {
    const s = String(v ?? "").replace(/"/g, '""');
    return s.includes(",") || s.includes('"') || s.includes("\n") ? `"${s}"` : s;
  };
  const csv = [headers, ...rows].map(r => r.map(escape).join(",")).join("\n");
  const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = filename; a.click();
  URL.revokeObjectURL(url);
}

/* ── Custom Tooltip ── */
function CustomTooltip({ active, payload, label }) {
  if (active && payload?.length) {
    return (
      <div className="rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-xs">
        <p className="font-semibold text-white mb-1">{label}</p>
        {payload.map((p, i) => (
          <p key={i} style={{ color: p.color || p.fill }}>
            {p.name}: Rs. {parseFloat(p.value || 0).toLocaleString()}
          </p>
        ))}
      </div>
    );
  }
  return null;
}

export default function ReportsPage() {
  const { t } = useTranslation();
  const { language } = useAppSettings();
  const maskAmount = usePrivateAmount();

  const [salesList, setSalesList] = useState([]);
  const [expenseList, setExpenseList] = useState([]);
  const [purchaseList, setPurchaseList] = useState([]);
  const [loading, setLoading] = useState(true);

  // Date range filter
  const thisMonthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10);
  const todayStr = new Date().toISOString().slice(0, 10);
  const [dateFrom, setDateFrom] = useState(thisMonthStart);
  const [dateTo, setDateTo] = useState(todayStr);
  const [activeReport, setActiveReport] = useState("overview");

  useEffect(() => {
    setLoading(true);
    Promise.allSettled([
      salesApi.list(),
      expensesApi.list(),
      purchasesApi.list(),
    ]).then(([sRes, eRes, pRes]) => {
      if (sRes.status === "fulfilled") setSalesList(sRes.value.data.results ?? sRes.value.data);
      if (eRes.status === "fulfilled") setExpenseList(eRes.value.data.results ?? eRes.value.data);
      if (pRes.status === "fulfilled") setPurchaseList(pRes.value.data.results ?? pRes.value.data);
    }).finally(() => setLoading(false));
  }, []);

  // Filter by date range
  const inRange = (dateStr) => {
    if (!dateStr) return false;
    return dateStr >= dateFrom && dateStr <= dateTo;
  };

  const filteredSales = salesList.filter(s => inRange(s.sale_date || s.date));
  const filteredExp = expenseList.filter(e => inRange(e.date));
  const filteredPurchases = purchaseList.filter(p => inRange(p.purchase_date));

  const totalSales = filteredSales.reduce((s, x) => s + parseFloat(x.total_amount || x.total || 0), 0);
  const totalExp = filteredExp.reduce((s, x) => s + parseFloat(x.amount || 0), 0);
  const totalPurchases = filteredPurchases.reduce((s, x) => s + parseFloat(x.total || 0), 0);
  const netProfit = totalSales - totalExp;

  // Monthly data (last 6 months)
  const monthlyData = Array.from({ length: 6 }, (_, i) => {
    const d = new Date(); d.setMonth(d.getMonth() - (5 - i));
    const key = d.toISOString().slice(0, 7);
    const sales = salesList.filter(s => (s.sale_date || s.date || "").startsWith(key))
      .reduce((s, x) => s + parseFloat(x.total_amount || x.total || 0), 0);
    const exp = expenseList.filter(e => (e.date || "").startsWith(key))
      .reduce((s, x) => s + parseFloat(x.amount || 0), 0);
    return { month: MONTHS[d.getMonth()], sales, expenses: exp, profit: sales - exp };
  });

  // Top products
  const productMap = {};
  salesList.forEach(sale => {
    (sale.items || []).forEach(item => {
      const name = item.product_name || "Unknown";
      if (!productMap[name]) productMap[name] = { name, qty: 0, revenue: 0 };
      productMap[name].qty += parseFloat(item.quantity || 0);
      productMap[name].revenue += parseFloat(item.quantity || 0) * parseFloat(item.unit_price || 0);
    });
  });
  const topProducts = Object.values(productMap).sort((a, b) => b.revenue - a.revenue).slice(0, 10);

  // CSV exports
  const exportSales = () => exportCSV(
    ["Invoice No", "Date", "Customer", "Total", "Paid", "Due", "Method", "Status"],
    filteredSales.map(s => [s.invoice_number, s.sale_date, s.customer_name || "", s.total_amount || s.total, s.paid_amount, s.due_amount, s.payment_method, s.status]),
    `sales_${dateFrom}_${dateTo}.csv`
  );

  const exportExpenses = () => exportCSV(
    ["Date", "Category", "Amount", "Method", "Description"],
    filteredExp.map(e => [e.date, e.category_name || "", e.amount, e.payment_method, e.description || ""]),
    `expenses_${dateFrom}_${dateTo}.csv`
  );

  const exportPurchases = () => exportCSV(
    ["Bill No", "Date", "Supplier", "Total", "Paid", "Due", "Status"],
    filteredPurchases.map(p => [p.bill_number, p.purchase_date, p.supplier_name || "", p.total, p.paid_amount, p.due_amount, p.status]),
    `purchases_${dateFrom}_${dateTo}.csv`
  );

  const exportProducts = () => exportCSV(
    ["Product", "Qty Sold", "Revenue"],
    topProducts.map(p => [p.name, p.qty, p.revenue.toFixed(2)]),
    `top_products.csv`
  );

  const exportAll = () => {
    exportSales();
    exportExpenses();
    exportPurchases();
  };

  const handlePrint = () => {
    document.body.classList.add("print-mode");
    window.print();
    setTimeout(() => document.body.classList.remove("print-mode"), 1000);
  };

  const TABS = [
    { key: "overview", label: "Overview" },
    { key: "sales", label: "Sales Detail" },
    { key: "expenses", label: "Expenses" },
    { key: "purchases", label: "Purchases" },
  ];

  return (
    <div>
      {/* Header */}
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">{t("reports")}</h1>
          <p className="text-sm text-navy-500">Business analytics and performance overview</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <button onClick={exportAll}
            className="flex items-center gap-2 rounded-xl border border-green-500/40 bg-green-500/10 px-4 py-2 text-sm font-semibold text-green-400 hover:bg-green-500/20 transition">
            <Download size={14} /> Export All CSV
          </button>
          <button onClick={handlePrint}
            className="flex items-center gap-2 rounded-xl border border-navy-700 px-4 py-2 text-sm font-semibold text-navy-300 hover:bg-navy-800">
            <Printer size={14} /> Print / PDF
          </button>
        </div>
      </div>

      {/* Date range filter */}
      <div className="mb-5 flex items-center gap-3 rounded-2xl border border-navy-800 bg-navy-900 px-4 py-3">
        <Calendar className="h-4 w-4 text-navy-400 shrink-0" />
        <p className="text-xs font-semibold text-navy-400 shrink-0">Date Range:</p>
        <input type="date" value={dateFrom} onChange={e => setDateFrom(e.target.value)}
          className="rounded-lg border border-navy-700 bg-navy-800 px-3 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none" />
        <span className="text-navy-500 text-xs">to</span>
        <input type="date" value={dateTo} onChange={e => setDateTo(e.target.value)}
          className="rounded-lg border border-navy-700 bg-navy-800 px-3 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none" />
        <span className="ml-auto text-xs text-navy-500">
          {filteredSales.length} sales · {filteredExp.length} expenses
        </span>
      </div>

      {/* KPI Cards */}
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[
          { label: "Sales", value: totalSales, icon: TrendingUp, color: "orange", sub: `${filteredSales.length} invoices` },
          { label: "Expenses", value: totalExp, icon: TrendingDown, color: "red", sub: `${filteredExp.length} entries` },
          { label: "Net Profit", value: netProfit, icon: DollarSign, color: netProfit >= 0 ? "green" : "red", sub: "Revenue - Expenses" },
          { label: "Purchases", value: totalPurchases, icon: Package, color: "blue", sub: `${filteredPurchases.length} bills` },
        ].map(({ label, value, icon: Icon, color, sub }) => (
          <div key={label} className="rounded-xl border border-navy-800 bg-navy-900 p-4">
            <div className="flex items-center justify-between mb-2">
              <p className="text-xs text-navy-500">{label}</p>
              <div className={`flex h-7 w-7 items-center justify-center rounded-lg bg-${color}-500/10`}>
                <Icon size={14} className={`text-${color}-400`} />
              </div>
            </div>
            <p className={`text-xl font-bold text-${color}-400`}>
              {maskAmount(value, v => `Rs. ${Math.round(v).toLocaleString()}`)}
            </p>
            <p className="text-xs text-navy-500 mt-1">{sub}</p>
          </div>
        ))}
      </div>

      {/* Report Tabs */}
      <div className="mb-5 flex gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1 w-fit overflow-x-auto">
        {TABS.map(tab => (
          <button key={tab.key} onClick={() => setActiveReport(tab.key)}
            className={`whitespace-nowrap rounded-lg px-4 py-2 text-xs font-semibold transition ${
              activeReport === tab.key ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"
            }`}>
            {tab.label}
          </button>
        ))}
      </div>

      {/* Overview Tab */}
      {activeReport === "overview" && (
        <>
          <div className="mb-5 grid grid-cols-1 gap-5 lg:grid-cols-2">
            <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
              <h3 className="mb-4 text-sm font-semibold text-white">Revenue vs Expenses (6 months)</h3>
              {loading ? <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div> : (
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={monthlyData} margin={{ top: 0, right: 8, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#1e2a3b" />
                    <XAxis dataKey="month" tick={{ fill: "#64748b", fontSize: 11 }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fill: "#64748b", fontSize: 10 }} axisLine={false} tickLine={false} width={55}
                      tickFormatter={v => `${(v / 1000).toFixed(0)}k`} />
                    <Tooltip content={<CustomTooltip />} cursor={{ fill: "rgba(249,115,22,0.05)" }} />
                    <Legend wrapperStyle={{ fontSize: "11px", paddingTop: "8px" }} />
                    <Bar dataKey="sales" name="Sales" fill="#f97316" radius={[3, 3, 0, 0]} />
                    <Bar dataKey="expenses" name="Expenses" fill="#ef4444" radius={[3, 3, 0, 0]} />
                    <Bar dataKey="profit" name="Profit" fill="#22c55e" radius={[3, 3, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
            <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
              <h3 className="mb-4 text-sm font-semibold text-white">Sales Trend</h3>
              {loading ? <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div> : (
                <ResponsiveContainer width="100%" height={200}>
                  <LineChart data={monthlyData} margin={{ top: 5, right: 8, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#1e2a3b" />
                    <XAxis dataKey="month" tick={{ fill: "#64748b", fontSize: 11 }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fill: "#64748b", fontSize: 10 }} axisLine={false} tickLine={false} width={55}
                      tickFormatter={v => `${(v / 1000).toFixed(0)}k`} />
                    <Tooltip content={<CustomTooltip />} />
                    <Line type="monotone" dataKey="sales" name="Sales" stroke="#f97316" strokeWidth={2.5}
                      dot={{ fill: "#f97316", r: 4 }} activeDot={{ r: 6 }} />
                    <Line type="monotone" dataKey="profit" name="Profit" stroke="#22c55e" strokeWidth={2}
                      dot={{ fill: "#22c55e", r: 3 }} />
                  </LineChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>

          {/* Top Products */}
          <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
            <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
              <h3 className="text-sm font-semibold text-white">Top Products by Revenue</h3>
              <button onClick={exportProducts}
                className="flex items-center gap-1.5 rounded-lg border border-navy-700 px-3 py-1.5 text-xs text-navy-300 hover:border-orange-500/50 hover:text-orange-400 transition">
                <Download className="h-3.5 w-3.5" /> CSV
              </button>
            </div>
            {topProducts.length === 0 ? (
              <div className="py-10 text-center text-sm text-navy-400">No product data</div>
            ) : (
              <>
                <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50">
                  <div className="col-span-1">#</div>
                  <div className="col-span-6">Product</div>
                  <div className="col-span-2 text-right">Qty Sold</div>
                  <div className="col-span-3 text-right">Revenue</div>
                </div>
                {topProducts.map((p, i) => (
                  <div key={p.name} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 transition text-sm">
                    <div className="col-span-1 text-navy-500 font-medium">{i + 1}</div>
                    <div className="col-span-6 text-white font-medium">{p.name}</div>
                    <div className="col-span-2 text-right text-navy-400">{p.qty.toLocaleString()}</div>
                    <div className="col-span-3 text-right text-orange-400 font-semibold">
                      {maskAmount(p.revenue, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                    </div>
                  </div>
                ))}
              </>
            )}
          </div>
        </>
      )}

      {/* Sales Detail Tab */}
      {activeReport === "sales" && (
        <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
            <h3 className="text-sm font-semibold text-white">Sales ({filteredSales.length})</h3>
            <button onClick={exportSales}
              className="flex items-center gap-1.5 rounded-lg border border-green-500/40 bg-green-500/10 px-3 py-1.5 text-xs font-semibold text-green-400 hover:bg-green-500/20 transition">
              <Download className="h-3.5 w-3.5" /> Download CSV
            </button>
          </div>
          {filteredSales.length === 0 ? (
            <div className="py-10 text-center text-sm text-navy-400">No sales in selected range</div>
          ) : (
            <>
              <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50">
                <div className="col-span-2">Invoice</div>
                <div className="col-span-2">Date</div>
                <div className="col-span-3">Customer</div>
                <div className="col-span-2 text-right">Total</div>
                <div className="col-span-2 text-right">Paid</div>
                <div className="col-span-1 text-right">Due</div>
              </div>
              {filteredSales.map(s => (
                <div key={s.id} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs">
                  <div className="col-span-2 font-medium text-orange-400">{s.invoice_number}</div>
                  <div className="col-span-2 text-navy-400">{s.sale_date}</div>
                  <div className="col-span-3 text-white truncate">{s.customer_name || "—"}</div>
                  <div className="col-span-2 text-right text-white font-semibold">Rs. {parseFloat(s.total_amount || s.total || 0).toLocaleString()}</div>
                  <div className="col-span-2 text-right text-green-400">Rs. {parseFloat(s.paid_amount || 0).toLocaleString()}</div>
                  <div className="col-span-1 text-right text-red-400">Rs. {parseFloat(s.due_amount || 0).toLocaleString()}</div>
                </div>
              ))}
              <div className="border-t border-navy-800 bg-navy-900/80 px-4 py-3 grid grid-cols-12 gap-2 text-xs font-bold">
                <div className="col-span-7 text-navy-400">Total ({filteredSales.length} records)</div>
                <div className="col-span-2 text-right text-white">Rs. {Math.round(totalSales).toLocaleString()}</div>
              </div>
            </>
          )}
        </div>
      )}

      {/* Expenses Detail Tab */}
      {activeReport === "expenses" && (
        <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
            <h3 className="text-sm font-semibold text-white">Expenses ({filteredExp.length})</h3>
            <button onClick={exportExpenses}
              className="flex items-center gap-1.5 rounded-lg border border-green-500/40 bg-green-500/10 px-3 py-1.5 text-xs font-semibold text-green-400 hover:bg-green-500/20 transition">
              <Download className="h-3.5 w-3.5" /> Download CSV
            </button>
          </div>
          {filteredExp.length === 0 ? (
            <div className="py-10 text-center text-sm text-navy-400">No expenses in selected range</div>
          ) : (
            <>
              <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50">
                <div className="col-span-2">Date</div>
                <div className="col-span-3">Category</div>
                <div className="col-span-4">Description</div>
                <div className="col-span-2 text-right">Amount</div>
                <div className="col-span-1 text-right">Method</div>
              </div>
              {filteredExp.map(e => (
                <div key={e.id} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs">
                  <div className="col-span-2 text-navy-400">{e.date}</div>
                  <div className="col-span-3 text-white">{e.category_name || "—"}</div>
                  <div className="col-span-4 text-navy-400 truncate">{e.description || "—"}</div>
                  <div className="col-span-2 text-right text-red-400 font-semibold">Rs. {parseFloat(e.amount).toLocaleString()}</div>
                  <div className="col-span-1 text-right text-navy-500">{e.payment_method}</div>
                </div>
              ))}
              <div className="border-t border-navy-800 bg-navy-900/80 px-4 py-3 grid grid-cols-12 gap-2 text-xs font-bold">
                <div className="col-span-9 text-navy-400">Total ({filteredExp.length} records)</div>
                <div className="col-span-2 text-right text-red-400">Rs. {Math.round(totalExp).toLocaleString()}</div>
              </div>
            </>
          )}
        </div>
      )}

      {/* Purchases Detail Tab */}
      {activeReport === "purchases" && (
        <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
            <h3 className="text-sm font-semibold text-white">Purchases ({filteredPurchases.length})</h3>
            <button onClick={exportPurchases}
              className="flex items-center gap-1.5 rounded-lg border border-green-500/40 bg-green-500/10 px-3 py-1.5 text-xs font-semibold text-green-400 hover:bg-green-500/20 transition">
              <Download className="h-3.5 w-3.5" /> Download CSV
            </button>
          </div>
          {filteredPurchases.length === 0 ? (
            <div className="py-10 text-center text-sm text-navy-400">No purchases in selected range</div>
          ) : (
            <>
              <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50">
                <div className="col-span-2">Bill No</div>
                <div className="col-span-2">Date</div>
                <div className="col-span-3">Supplier</div>
                <div className="col-span-2 text-right">Total</div>
                <div className="col-span-2 text-right">Paid</div>
                <div className="col-span-1 text-right">Due</div>
              </div>
              {filteredPurchases.map(p => (
                <div key={p.id} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs">
                  <div className="col-span-2 font-medium text-blue-400">{p.bill_number}</div>
                  <div className="col-span-2 text-navy-400">{p.purchase_date}</div>
                  <div className="col-span-3 text-white truncate">{p.supplier_name || "—"}</div>
                  <div className="col-span-2 text-right text-white font-semibold">Rs. {parseFloat(p.total || 0).toLocaleString()}</div>
                  <div className="col-span-2 text-right text-green-400">Rs. {parseFloat(p.paid_amount || 0).toLocaleString()}</div>
                  <div className="col-span-1 text-right text-red-400">Rs. {parseFloat(p.due_amount || 0).toLocaleString()}</div>
                </div>
              ))}
              <div className="border-t border-navy-800 bg-navy-900/80 px-4 py-3 grid grid-cols-12 gap-2 text-xs font-bold">
                <div className="col-span-7 text-navy-400">Total ({filteredPurchases.length} records)</div>
                <div className="col-span-2 text-right text-white">Rs. {Math.round(totalPurchases).toLocaleString()}</div>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
}
