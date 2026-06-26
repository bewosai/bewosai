import { useState, useEffect } from "react";
import { Printer, TrendingUp, TrendingDown, DollarSign, Package } from "lucide-react";
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Legend, Cell
} from "recharts";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import { reports as reportsApi, sales as salesApi, expenses as expensesApi } from "../api/index.js";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const PERIODS = ["Daily", "Weekly", "Monthly", "Yearly"];

/* ─── Custom Tooltip ─── */
function CustomTooltip({ active, payload, label }) {
  if (active && payload && payload.length) {
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

  const [period, setPeriod] = useState("Monthly");
  const [salesList, setSalesList] = useState([]);
  const [expenseList, setExpenseList] = useState([]);
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    Promise.allSettled([
      reportsApi.dashboard(),
      salesApi.list(),
      expensesApi.list(),
    ]).then(([dashRes, salesRes, expRes]) => {
      if (dashRes.status === "fulfilled") setDashboard(dashRes.value.data);
      if (salesRes.status === "fulfilled") setSalesList(salesRes.value.data.results ?? salesRes.value.data);
      if (expRes.status === "fulfilled") setExpenseList(expRes.value.data.results ?? expRes.value.data);
    }).finally(() => setLoading(false));
  }, []);

  // Monthly data (last 6 months)
  const monthlyData = Array.from({ length: 6 }, (_, i) => {
    const d = new Date();
    d.setMonth(d.getMonth() - (5 - i));
    const key = d.toISOString().slice(0, 7);
    const sales = salesList.filter(s => (s.sale_date || s.date || "").startsWith(key))
      .reduce((s, x) => s + parseFloat(x.total_amount || 0), 0);
    const exp = expenseList.filter(e => (e.date || "").startsWith(key))
      .reduce((s, x) => s + parseFloat(x.amount || 0), 0);
    const profit = sales - exp;
    return { month: MONTHS[d.getMonth()], sales, expenses: exp, profit };
  });

  // Sales trend (monthly)
  const salesTrend = monthlyData.map(d => ({ month: d.month, revenue: d.sales }));

  // Top products from sales items
  const productMap = {};
  salesList.forEach(sale => {
    (sale.items || []).forEach(item => {
      const name = item.product_name || item.name || "Unknown";
      if (!productMap[name]) productMap[name] = { name, qty: 0, revenue: 0 };
      productMap[name].qty += parseFloat(item.quantity || 0);
      productMap[name].revenue += (parseFloat(item.quantity || 0) * parseFloat(item.unit_price || 0));
    });
  });
  const topProducts = Object.values(productMap).sort((a, b) => b.revenue - a.revenue).slice(0, 5);

  // KPI values
  const thisMonth = new Date().toISOString().slice(0, 7);
  const totalSalesMonth = salesList.filter(s => (s.sale_date || s.date || "").startsWith(thisMonth))
    .reduce((s, x) => s + parseFloat(x.total_amount || 0), 0);
  const totalExpMonth = expenseList.filter(e => (e.date || "").startsWith(thisMonth))
    .reduce((s, x) => s + parseFloat(x.amount || 0), 0);
  const netProfit = totalSalesMonth - totalExpMonth;

  const handlePrint = () => {
    document.body.classList.add("print-mode");
    window.print();
    setTimeout(() => document.body.classList.remove("print-mode"), 1000);
  };

  return (
    <div>
      {/* Header */}
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">{t("reports")}</h1>
          <p className="text-sm text-navy-500">Business analytics and performance overview</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex gap-1 rounded-xl bg-navy-900 border border-navy-800 p-1">
            {PERIODS.map(p => (
              <button key={p} onClick={() => setPeriod(p)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${period === p ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}>
                {p}
              </button>
            ))}
          </div>
          <button onClick={handlePrint}
            className="flex items-center gap-2 rounded-xl border border-navy-700 px-4 py-2 text-sm font-semibold text-navy-300 hover:bg-navy-800">
            <Printer size={14} /> Export PDF
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs text-navy-500">Total Sales</p>
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-orange-500/10">
              <TrendingUp size={14} className="text-orange-400" />
            </div>
          </div>
          <p className="text-xl font-bold text-white">{maskAmount(totalSalesMonth, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
          <p className="text-xs text-navy-500 mt-1">This month</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs text-navy-500">Total Expenses</p>
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-red-500/10">
              <TrendingDown size={14} className="text-red-400" />
            </div>
          </div>
          <p className="text-xl font-bold text-white">{maskAmount(totalExpMonth, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
          <p className="text-xs text-navy-500 mt-1">This month</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs text-navy-500">Net Profit</p>
            <div className={`flex h-7 w-7 items-center justify-center rounded-lg ${netProfit >= 0 ? "bg-green-500/10" : "bg-red-500/10"}`}>
              <DollarSign size={14} className={netProfit >= 0 ? "text-green-400" : "text-red-400"} />
            </div>
          </div>
          <p className={`text-xl font-bold ${netProfit >= 0 ? "text-green-400" : "text-red-400"}`}>
            {maskAmount(netProfit, v => `Rs. ${Math.round(v).toLocaleString()}`)}
          </p>
          <p className="text-xs text-navy-500 mt-1">This month</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs text-navy-500">Total Invoices</p>
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-blue-500/10">
              <Package size={14} className="text-blue-400" />
            </div>
          </div>
          <p className="text-xl font-bold text-white">{salesList.length}</p>
          <p className="text-xs text-navy-500 mt-1">All time</p>
        </div>
      </div>

      {/* Charts Row */}
      <div className="mb-5 grid grid-cols-1 gap-5 lg:grid-cols-2">
        {/* Revenue vs Expenses Bar Chart */}
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <h3 className="mb-4 text-sm font-semibold text-white">Revenue vs Expenses vs Profit</h3>
          {loading ? (
            <div className="flex h-48 items-center justify-center text-sm text-navy-400">{t("loading")}</div>
          ) : (
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

        {/* Sales Trend Line Chart */}
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <h3 className="mb-4 text-sm font-semibold text-white">Sales Trend</h3>
          {loading ? (
            <div className="flex h-48 items-center justify-center text-sm text-navy-400">{t("loading")}</div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={salesTrend} margin={{ top: 5, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e2a3b" />
                <XAxis dataKey="month" tick={{ fill: "#64748b", fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: "#64748b", fontSize: 10 }} axisLine={false} tickLine={false} width={55}
                  tickFormatter={v => `${(v / 1000).toFixed(0)}k`} />
                <Tooltip content={<CustomTooltip />} />
                <Line type="monotone" dataKey="revenue" name="Revenue" stroke="#f97316" strokeWidth={2.5}
                  dot={{ fill: "#f97316", r: 4 }} activeDot={{ r: 6 }} />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* Top Products Table */}
      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
        <div className="px-4 py-3 border-b border-navy-800">
          <h3 className="text-sm font-semibold text-white">Top Products by Revenue</h3>
        </div>
        {topProducts.length === 0 ? (
          <div className="py-10 text-center text-sm text-navy-400">No product data available</div>
        ) : (
          <>
            <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50">
              <div className="col-span-1">#</div>
              <div className="col-span-6">Product</div>
              <div className="col-span-2 text-right">Qty Sold</div>
              <div className="col-span-3 text-right">Revenue</div>
            </div>
            {topProducts.map((p, i) => (
              <div key={p.name}
                className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 transition text-sm">
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
    </div>
  );
}
