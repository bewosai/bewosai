import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { reports as reportsApi } from "../api";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useDateFormat } from "../context/AppSettingsContext";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from "recharts";
import {
  TrendingUp, TrendingDown, AlertTriangle, ShoppingCart,
  Package, Plus, Wallet, ArrowUpRight, ArrowDownRight,
  Users, Receipt, BarChart3, Loader,
} from "lucide-react";

const MONTHS_EN = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
const MONTHS_NE = ["बैशाख","जेठ","असार","श्रावण","भाद्र","असोज","कार्तिक","मंसिर","पुष","माघ","फागुन","चैत"];

function KpiCard({ label, value, sub, icon: Icon, iconBg, trend, onClick }) {
  return (
    <button
      onClick={onClick}
      className="rounded-2xl border border-navy-800 bg-navy-900 p-5 text-left transition hover:border-orange-500/30 hover:shadow-sm w-full"
    >
      <div className="flex items-start justify-between">
        <div className={`flex h-10 w-10 items-center justify-center rounded-xl ${iconBg}`}>
          <Icon className="h-5 w-5" />
        </div>
        {trend !== undefined && (
          <span className={`flex items-center gap-0.5 text-xs font-medium ${trend >= 0 ? "text-green-500" : "text-red-400"}`}>
            {trend >= 0 ? <ArrowUpRight className="h-3.5 w-3.5" /> : <ArrowDownRight className="h-3.5 w-3.5" />}
            {Math.abs(trend)}%
          </span>
        )}
      </div>
      <p className="mt-3 text-2xl font-bold text-white">{value}</p>
      <p className="mt-0.5 text-sm text-navy-500">{label}</p>
      {sub && <p className="mt-1 text-xs text-navy-600">{sub}</p>}
    </button>
  );
}

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-navy-800 bg-navy-900 p-3 shadow-xl">
      <p className="text-xs font-semibold text-white mb-2">{label}</p>
      {payload.map((p) => (
        <p key={p.name} className="text-xs" style={{ color: p.color }}>
          {p.name}: Rs. {Number(p.value).toLocaleString("en-IN", { maximumFractionDigits: 0 })}
        </p>
      ))}
    </div>
  );
};

export default function DashboardPage() {
  const navigate = useNavigate();
  const { t, language } = useTranslation();
  const fmt = usePrivateAmount();
  const formatDate = useDateFormat();
  const [data, setData] = useState(null);
  const [monthly, setMonthly] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      reportsApi.dashboard().catch(() => ({ data: null })),
      reportsApi.monthly().catch(() => ({ data: [] })),
    ]).then(([dash, mon]) => {
      setData(dash.data);
      const raw = Array.isArray(mon.data) ? mon.data : [];
      setMonthly(raw.map((m) => ({
        name: (language === "ne" ? MONTHS_NE : MONTHS_EN)[m.month - 1] || `M${m.month}`,
        [t("revenue")]: m.revenue,
        [t("expenses")]: m.expenses,
        [t("profit")]: m.profit,
      })));
    }).finally(() => setLoading(false));
  }, [language]);

  const f = (v) => fmt(v || 0);

  const kpis = [
    { label: t("todaySales"), value: f(data?.sales_today), icon: ShoppingCart, iconBg: "bg-blue-100 text-blue-600", path: "/sales" },
    { label: t("monthSales"), value: f(data?.sales_month), icon: TrendingUp, iconBg: "bg-green-100 text-green-600", path: "/sales" },
    { label: t("receivable"), value: f(data?.total_receivable), icon: Wallet, iconBg: "bg-orange-100 text-orange-600", path: "/payments" },
    { label: t("totalExpenses"), value: f(data?.expenses_month), icon: TrendingDown, iconBg: "bg-red-100 text-red-500", path: "/expenses" },
    { label: t("netProfit"), value: f(data?.profit_month), icon: BarChart3, iconBg: "bg-purple-100 text-purple-600", path: "/reports" },
    { label: t("lowStock"), value: data?.low_stock_count ?? "–", icon: Package, iconBg: "bg-yellow-100 text-yellow-600", path: "/inventory/low-stock" },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">{t("dashboard")}</h1>
          <p className="mt-1 text-sm text-navy-500">
            {language === "ne" ? "तपाईंको व्यवसायको अवलोकन" : "Overview of your business performance"}
          </p>
        </div>
        <button
          onClick={() => navigate("/sales")}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition"
        >
          <Plus className="h-4 w-4" />{t("newInvoice")}
        </button>
      </div>

      {/* KPI Cards */}
      {loading ? (
        <div className="flex justify-center py-12"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {kpis.map((k) => (
            <KpiCard key={k.label} {...k} onClick={() => navigate(k.path)} />
          ))}
        </div>
      )}

      {/* Profit/Loss Chart */}
      <div className="rounded-2xl border border-navy-800 bg-navy-900 p-5">
        <div className="mb-5 flex items-center justify-between">
          <div>
            <h2 className="font-bold text-white">{t("profitLoss")}</h2>
            <p className="text-xs text-navy-500 mt-0.5">
              {language === "ne" ? "पछिल्लो १२ महिना" : "Last 12 months"}
            </p>
          </div>
          <button
            onClick={() => navigate("/reports")}
            className="text-xs font-medium text-orange-500 hover:text-orange-400"
          >
            {language === "ne" ? "विस्तृत हेर्नुहोस् →" : "View detailed →"}
          </button>
        </div>
        {monthly.length === 0 ? (
          <div className="flex items-center justify-center py-12 text-center">
            <div>
              <BarChart3 className="mx-auto h-10 w-10 text-navy-600 mb-2" />
              <p className="text-sm text-navy-500">{language === "ne" ? "अहिले डेटा छैन" : "No data yet — start recording sales"}</p>
            </div>
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={monthly} margin={{ top: 0, right: 10, left: -10, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--color-navy-800)" />
              <XAxis dataKey="name" tick={{ fill: "var(--color-navy-500)", fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: "var(--color-navy-500)", fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={(v) => `${(v/1000).toFixed(0)}k`} />
              <Tooltip content={<CustomTooltip />} />
              <Legend wrapperStyle={{ fontSize: "12px", color: "var(--color-navy-400)" }} />
              <Bar dataKey={t("revenue")} fill="#3b82f6" radius={[4, 4, 0, 0]} maxBarSize={30} />
              <Bar dataKey={t("expenses")} fill="#ef4444" radius={[4, 4, 0, 0]} maxBarSize={30} />
              <Bar dataKey={t("profit")} fill="#f59e0b" radius={[4, 4, 0, 0]} maxBarSize={30} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>

      {/* Bottom row */}
      <div className="grid gap-5 lg:grid-cols-2">
        {/* Recent Sales */}
        <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="flex items-center justify-between border-b border-navy-800 px-5 py-3.5">
            <h2 className="font-semibold text-white">{t("recentSales")}</h2>
            <button onClick={() => navigate("/sales")} className="text-xs text-orange-500 hover:text-orange-400">
              {language === "ne" ? "सबै हेर्नुहोस् →" : "View all →"}
            </button>
          </div>
          <div className="divide-y divide-navy-800">
            {data?.recent_sales?.length ? (
              data.recent_sales.slice(0, 5).map((sale) => (
                <div key={sale.id} className="flex items-center gap-3 px-5 py-3.5">
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-blue-100">
                    <ShoppingCart className="h-4 w-4 text-blue-600" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium text-white truncate">{sale.invoice_number}</p>
                    <p className="text-xs text-navy-500">{sale.customer_name || (language === "ne" ? "वाक-इन" : "Walk-in")} · {formatDate(sale.sale_date)}</p>
                  </div>
                  <div className="text-right shrink-0">
                    <p className="text-sm font-bold text-white">{f(sale.total)}</p>
                    <span className={`text-xs font-medium ${sale.status === "CONFIRMED" ? "text-green-500" : "text-navy-500"}`}>{sale.status}</span>
                  </div>
                </div>
              ))
            ) : (
              <div className="flex flex-col items-center py-10 text-center">
                <ShoppingCart className="h-8 w-8 text-navy-600 mb-2" />
                <p className="text-sm text-navy-500">{language === "ne" ? "कुनै बिक्री छैन" : "No sales yet"}</p>
              </div>
            )}
          </div>
        </div>

        {/* Quick Actions + Alerts */}
        <div className="space-y-4">
          {/* Low stock alert */}
          {(data?.low_stock_count || 0) > 0 && (
            <button
              onClick={() => navigate("/inventory/low-stock")}
              className="w-full flex items-center gap-3 rounded-2xl border border-red-500/30 bg-red-500/5 px-5 py-4 text-left hover:bg-red-500/10 transition"
            >
              <AlertTriangle className="h-5 w-5 text-red-500 shrink-0" />
              <div>
                <p className="text-sm font-semibold text-white">
                  {data.low_stock_count} {language === "ne" ? "वस्तु कम स्टकमा" : "items low on stock"}
                </p>
                <p className="text-xs text-navy-500 mt-0.5">{language === "ne" ? "स्टक पुनः अर्डर गर्नुहोस्" : "Reorder to avoid stockouts"}</p>
              </div>
            </button>
          )}

          {/* Quick Actions */}
          <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
            <h2 className="font-semibold text-white mb-3 text-sm">{language === "ne" ? "द्रुत कार्यहरू" : "Quick Actions"}</h2>
            <div className="grid grid-cols-2 gap-2.5">
              {[
                { label: t("newInvoice"), path: "/sales", icon: ShoppingCart, color: "text-blue-500", bg: "bg-blue-50" },
                { label: t("newPurchase"), path: "/purchases", icon: Package, color: "text-purple-500", bg: "bg-purple-50" },
                { label: t("newExpense"), path: "/expenses", icon: Receipt, color: "text-red-500", bg: "bg-red-50" },
                { label: t("newParty"), path: "/parties", icon: Users, color: "text-green-500", bg: "bg-green-50" },
              ].map(({ label, path, icon: Icon, color, bg }) => (
                <button
                  key={label}
                  onClick={() => navigate(path)}
                  className="flex items-center gap-2 rounded-xl border border-navy-800 px-3 py-3 text-sm font-medium text-white transition hover:border-orange-500/40 hover:bg-navy-800"
                >
                  <div className={`flex h-7 w-7 items-center justify-center rounded-lg ${bg}`}>
                    <Icon className={`h-4 w-4 ${color}`} />
                  </div>
                  <span className="text-sm text-navy-300">{label}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
