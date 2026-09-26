import { useState, useEffect, lazy, Suspense } from "react";
import { useNavigate } from "react-router-dom";
import { reports as reportsApi } from "../api";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useDateFormat } from "../context/AppSettingsContext";

const MonthlyChart = lazy(() => import("../components/dashboard/MonthlyChart"));
import {
  TrendingUp, TrendingDown, ShoppingCart,
  Package, Plus, Wallet, ArrowUpRight, ArrowDownRight, ArrowDownLeft,
  Users, Receipt, BarChart3, Loader, SlidersHorizontal, X, Check,
} from "lucide-react";

// Which KPI tiles a viewer wants to see is a personal display preference,
// not business data — kept in localStorage rather than sent to the server.
const VISIBLE_KPIS_KEY = "bw_dashboard_visible_kpis";
const MIN_VISIBLE_KPIS = 3;
// Shown until a viewer customizes their own set — the handful of numbers
// that answer "how's the business right now" without crowding the page;
// everything else is one tap away via the Customize button.
// Which permission module each dashboard card's number comes from.
const KPI_MODULE = {
  sales_today: "sales", collection_today: "sales", purchases_today: "purchases", expenses_today: "expenses",
  receivable: "parties", payable: "parties", cash_balance: "reports", net_profit: "reports", low_stock: "inventory",
};
const DEFAULT_VISIBLE_KPI_KEYS = ["sales_today", "receivable", "payable", "net_profit", "low_stock"];

function loadVisibleKpiKeys(allKeys) {
  try {
    const saved = JSON.parse(localStorage.getItem(VISIBLE_KPIS_KEY));
    if (Array.isArray(saved) && saved.length >= MIN_VISIBLE_KPIS) {
      // Drop any key that no longer exists (a KPI was renamed/removed since
      // this was saved) rather than let a stale key silently do nothing.
      const filtered = saved.filter((k) => allKeys.includes(k));
      if (filtered.length >= MIN_VISIBLE_KPIS) return filtered;
    }
  } catch {
    // fall through to the default set below
  }
  return DEFAULT_VISIBLE_KPI_KEYS.filter((k) => allKeys.includes(k));
}

function DashboardCustomizeModal({ kpis, visibleKeys, onSave, onClose }) {
  const [selected, setSelected] = useState(new Set(visibleKeys));

  const toggle = (key) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(key)) {
        if (next.size <= MIN_VISIBLE_KPIS) return prev; // can't go below the minimum
        next.delete(key);
      } else {
        next.add(key);
      }
      return next;
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-1 flex items-center justify-between">
          <h2 className="font-bold text-white">Customize Dashboard</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        <p className="mb-4 text-xs text-navy-500">
          Choose which cards to show — at least {MIN_VISIBLE_KPIS}, up to all of them.
        </p>
        <div className="max-h-80 space-y-1 overflow-y-auto">
          {kpis.map(({ key, label, icon: Icon }) => {
            const checked = selected.has(key);
            const disabled = checked && selected.size <= MIN_VISIBLE_KPIS;
            return (
              <button
                key={key}
                type="button"
                onClick={() => toggle(key)}
                disabled={disabled}
                className={`flex w-full items-center gap-3 rounded-xl border px-3 py-2.5 text-left transition ${
                  checked ? "border-orange-500/40 bg-orange-500/5" : "border-navy-800 hover:bg-navy-800/40"
                } ${disabled ? "cursor-not-allowed opacity-60" : ""}`}
              >
                <Icon className="h-4 w-4 shrink-0 text-navy-400" />
                <span className="flex-1 text-sm text-white">{label}</span>
                <span className={`flex h-5 w-5 items-center justify-center rounded border ${
                  checked ? "border-orange-500 bg-orange-500/20 text-orange-400" : "border-navy-700"
                }`}>
                  {checked && <Check className="h-3 w-3" />}
                </span>
              </button>
            );
          })}
        </div>
        <div className="mt-5 flex gap-3">
          <button onClick={onClose} className="flex-1 rounded-xl border border-navy-700 py-2.5 text-sm font-medium text-navy-400 hover:bg-navy-800">
            Cancel
          </button>
          <button
            onClick={() => onSave([...selected])}
            className="flex-1 rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

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

  const allKpis = [
    { key: "sales_today",      label: t("todaySales"),     value: f(data?.sales_today),      icon: ShoppingCart,  iconBg: "bg-blue-100 text-blue-600",    path: "/sales",                  sub: language === "ne" ? "आजको बिक्री" : "Today" },
    { key: "purchases_today",  label: "Today's Purchase",  value: f(data?.purchases_today),  icon: Receipt,       iconBg: "bg-purple-100 text-purple-600", path: "/purchases",              sub: language === "ne" ? "आजको खरिद" : "Today" },
    { key: "collection_today", label: "Today's Collection",value: f(data?.collection_today), icon: Wallet,        iconBg: "bg-green-100 text-green-600",   path: "/payments",               sub: language === "ne" ? "आज संकलन" : "Cash + Bank" },
    { key: "expenses_today",   label: "Today's Expense",   value: f(data?.expenses_today),   icon: TrendingDown,  iconBg: "bg-red-100 text-red-500",       path: "/expenses",               sub: language === "ne" ? "आजको खर्च" : "Today" },
    { key: "receivable",       label: t("receivable"),     value: f(data?.total_receivable), icon: ArrowUpRight,  iconBg: "bg-orange-100 text-orange-600", path: "/payments",               sub: language === "ne" ? "पाउनु पर्ने" : "Outstanding" },
    { key: "payable",          label: "Payable",           value: f(data?.total_payable),    icon: ArrowDownRight,iconBg: "bg-red-100 text-red-500",       path: "/purchases",              sub: language === "ne" ? "बुझाउनु पर्ने" : "Outstanding" },
    { key: "cash_balance",     label: "Cash Balance",      value: f(data?.cash_balance),     icon: Wallet,        iconBg: "bg-yellow-100 text-yellow-600", path: "/banking",                sub: language === "ne" ? "नगद मौज्दात" : "Estimated" },
    { key: "net_profit",       label: t("netProfit"),      value: f(data?.profit_month),     icon: BarChart3,     iconBg: "bg-purple-100 text-purple-600", path: "/reports",                sub: language === "ne" ? "यो महिना" : "This month" },
    { key: "low_stock",        label: t("lowStock"),       value: data?.low_stock_count ?? "–", icon: Package,   iconBg: "bg-yellow-100 text-yellow-600", path: "/inventory/low-stock",    sub: language === "ne" ? "कम स्टक" : "Items" },
  ];
  // The server zeroes figures the viewer may not see and names those modules in
  // `restricted`; leave those cards out rather than show a misleading 0.
  const restricted = data?.restricted || [];
  const kpis = allKpis.filter((k) => !restricted.includes(KPI_MODULE[k.key]));
  const allKpiKeys = kpis.map((k) => k.key);
  const [visibleKeys, setVisibleKeys] = useState(() => loadVisibleKpiKeys(allKpiKeys));
  const [showCustomize, setShowCustomize] = useState(false);
  const visibleKpis = kpis.filter((k) => visibleKeys.includes(k.key));

  const saveVisibleKeys = (keys) => {
    setVisibleKeys(keys);
    localStorage.setItem(VISIBLE_KPIS_KEY, JSON.stringify(keys));
    setShowCustomize(false);
  };

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
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowCustomize(true)}
            title="Customize dashboard cards"
            className="flex items-center gap-2 rounded-xl border border-navy-700 px-3 py-2.5 text-sm font-medium text-navy-400 hover:bg-navy-800 transition"
          >
            <SlidersHorizontal className="h-4 w-4" />
          </button>
          <button
            onClick={() => navigate("/sales?action=new")}
            className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition"
          >
            <Plus className="h-4 w-4" />{t("newInvoice")}
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      {loading ? (
        <div className="flex justify-center py-12"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {visibleKpis.map((k) => (
            <KpiCard key={k.key} {...k} onClick={() => navigate(k.path)} />
          ))}
        </div>
      )}

      {showCustomize && (
        <DashboardCustomizeModal
          kpis={kpis}
          visibleKeys={visibleKeys}
          onSave={saveVisibleKeys}
          onClose={() => setShowCustomize(false)}
        />
      )}

      {/* Top Items (when data available) */}
      {!loading && data?.top_items?.length > 0 && (
        <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="flex items-center justify-between border-b border-navy-800 px-5 py-3.5">
            <h2 className="font-semibold text-white">{language === "ne" ? "सर्वाधिक बिक्री वस्तु" : "Top Selling Items"}</h2>
            <button onClick={() => navigate("/inventory")} className="text-xs text-orange-500 hover:text-orange-400">
              {language === "ne" ? "स्टक हेर्नुहोस् →" : "View stock →"}
            </button>
          </div>
          <div className="divide-y divide-navy-800">
            {data.top_items.map((item, i) => (
              <div key={i} className="flex items-center gap-3 px-5 py-3">
                <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-orange-500/10 text-xs font-bold text-orange-500">
                  {i + 1}
                </div>
                <p className="flex-1 text-sm text-white truncate">{item.product_name}</p>
                <div className="text-right shrink-0">
                  <p className="text-sm font-semibold text-white">{f(item.total_revenue)}</p>
                  <p className="text-[10px] text-navy-500">{item.total_qty} units</p>
                </div>
              </div>
            ))}
          </div>
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
          <Suspense fallback={<div style={{ height: 260 }} />}>
            <MonthlyChart
              data={monthly}
              labels={{ revenue: t("revenue"), expenses: t("expenses"), profit: t("profit") }}
            />
          </Suspense>
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
                    <p className="text-xs text-navy-500">{sale.customer_name || (language === "ne" ? "नगद बिक्री" : "Cash Sales")} · {formatDate(sale.sale_date)}</p>
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
          {/* Quick Actions */}
          <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
            <h2 className="font-semibold text-white mb-3 text-sm">{language === "ne" ? "द्रुत कार्यहरू" : "Quick Actions"}</h2>
            <div className="grid grid-cols-2 gap-2.5">
              {[
                { label: t("newInvoice"), path: "/sales?action=new", icon: ShoppingCart, color: "text-blue-500", bg: "bg-blue-50" },
                { label: t("newPurchase"), path: "/purchases?action=add", icon: Package, color: "text-purple-500", bg: "bg-purple-50" },
                { label: t("newExpense"), path: "/expenses?action=add", icon: Receipt, color: "text-red-500", bg: "bg-red-50" },
                { label: t("newParty"), path: "/parties?action=add", icon: Users, color: "text-green-500", bg: "bg-green-50" },
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
