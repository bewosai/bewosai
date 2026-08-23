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
  Package, Plus, Wallet, ArrowUpRight, ArrowDownRight, ArrowDownLeft,
  Users, Receipt, BarChart3, Loader, Bell, ChevronRight, SlidersHorizontal, X, Check,
} from "lucide-react";

// Which KPI tiles a viewer wants to see is a personal display preference,
// not business data — kept in localStorage rather than sent to the server.
const VISIBLE_KPIS_KEY = "bw_dashboard_visible_kpis";
const MIN_VISIBLE_KPIS = 3;

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
    // fall through to "show everything" below
  }
  return allKeys;
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

/**
 * Proactive reminder about money owed to the business — shown right on the
 * Dashboard (not buried in the dedicated Reports section) since a pending
 * payment is exactly the kind of thing you should see the moment you open
 * the app. Falls back to just the total (already available on every plan)
 * if the per-customer breakdown can't be fetched — e.g. Reports is
 * plan-gated or the request fails — so a Free-plan business still gets a
 * useful reminder, just without the itemized list.
 */
function PaymentReminderBanner({ totalReceivable, fmt, language }) {
  const navigate = useNavigate();
  const [debtors, setDebtors] = useState(null);

  useEffect(() => {
    if (!totalReceivable || totalReceivable <= 0) return;
    reportsApi.receivableAging()
      .then((r) => setDebtors(r.data?.top_debtors || []))
      .catch(() => setDebtors(null));
  }, [totalReceivable]);

  if (!totalReceivable || totalReceivable <= 0) return null;

  return (
    <div className="rounded-2xl border border-orange-500/30 bg-orange-500/5 p-4 sm:p-5">
      <div className="flex items-start gap-3">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-orange-500/15">
          <Bell className="h-4 w-4 text-orange-400" />
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-white">
            {language === "ne" ? "तपाईंले पाउनुपर्ने रकम बाँकी छ" : "You have money pending to receive"}
            {" — "}
            <span className="text-orange-400">{fmt(totalReceivable)}</span>
          </p>
          {debtors && debtors.length > 0 && (
            <div className="mt-3 space-y-1.5">
              {debtors.slice(0, 3).map((d) => (
                <button
                  key={d.customer_id ?? d.customer__name}
                  onClick={() => navigate("/payments")}
                  className="flex w-full items-center justify-between gap-2 rounded-lg px-2 py-1 text-left text-xs text-navy-300 hover:bg-navy-800/60"
                >
                  <span className="truncate">
                    {d.customer__name || "Walk-in"} · {d.invoice_count} invoice{d.invoice_count !== 1 ? "s" : ""}
                  </span>
                  <span className="shrink-0 font-semibold text-orange-300">{fmt(d.total_due)}</span>
                </button>
              ))}
            </div>
          )}
          <button
            onClick={() => navigate("/payments")}
            className="mt-3 flex items-center gap-1 text-xs font-semibold text-orange-400 hover:text-orange-300"
          >
            {language === "ne" ? "हेर्नुहोस् र संकलन गर्नुहोस्" : "View & Collect"} <ChevronRight className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>
    </div>
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
            onClick={() => navigate("/sales")}
            className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition"
          >
            <Plus className="h-4 w-4" />{t("newInvoice")}
          </button>
        </div>
      </div>

      {!loading && (
        <PaymentReminderBanner totalReceivable={data?.total_receivable} fmt={f} language={language} />
      )}

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
