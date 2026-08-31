import { useState, useEffect } from "react";
import {
  Printer, TrendingUp, TrendingDown, DollarSign, Package, Download, FileText, Calendar,
  Boxes, ListChecks, BookOpen, Users, Wallet, Landmark, Receipt, ChevronRight, Search, ArrowLeft,
} from "lucide-react";
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Legend,
} from "recharts";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import {
  reports as reportsApi, sales as salesApi, expenses as expensesApi, purchases as purchasesApi,
  parties as partiesApi,
} from "../api/index.js";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/* Local calendar date as YYYY-MM-DD — unlike `.toISOString().slice(0,10)`, this doesn't
   shift to the previous day for timezones ahead of UTC (e.g. Nepal, UTC+5:45). */
function localISODate(d) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

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
  const thisMonthStart = localISODate(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const todayStr = localISODate(new Date());
  const [dateFrom, setDateFrom] = useState(thisMonthStart);
  const [dateTo, setDateTo] = useState(todayStr);
  const [activeReport, setActiveReport] = useState("overview");

  // Server-side report tabs (Profit & Loss, Stock, Aging, Day Book)
  const [profitData, setProfitData] = useState(null);
  const [profitLoading, setProfitLoading] = useState(false);
  const [stockData, setStockData] = useState(null);
  const [stockLoading, setStockLoading] = useState(false);
  const [agingData, setAgingData] = useState(null);
  const [agingLoading, setAgingLoading] = useState(false);
  const [dayBookDate, setDayBookDate] = useState(todayStr);
  const [dayBookData, setDayBookData] = useState(null);
  const [dayBookLoading, setDayBookLoading] = useState(false);

  // Stock report (full per-product valuation) — new
  const [stockReport, setStockReport] = useState(null);
  const [stockReportLoading, setStockReportLoading] = useState(false);

  // All Transactions tab
  const [allTxData, setAllTxData] = useState(null);
  const [allTxLoading, setAllTxLoading] = useState(false);
  const [allTxType, setAllTxType] = useState("");

  // Party Statement tab
  const [partyList, setPartyList] = useState([]);
  const [partyListLoading, setPartyListLoading] = useState(false);
  const [partySearch, setPartySearch] = useState("");
  const [selectedParty, setSelectedParty] = useState(null);
  const [partyLedger, setPartyLedger] = useState(null);
  const [partyLedgerLoading, setPartyLedgerLoading] = useState(false);

  // Cash In Hand tab
  const [cashHandData, setCashHandData] = useState(null);
  const [cashHandLoading, setCashHandLoading] = useState(false);

  // Bank Statement tab
  const [bankAccounts, setBankAccounts] = useState([]);
  const [bankAccountsLoading, setBankAccountsLoading] = useState(false);
  const [selectedAccount, setSelectedAccount] = useState(null);
  const [bankStatement, setBankStatement] = useState(null);
  const [bankStatementLoading, setBankStatementLoading] = useState(false);

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

  // Profit & Loss tab (and Overview's Net Profit card, which shows the same
  // backend-computed figure — not a separately-derived one) — refetch
  // whenever the date range or tab changes.
  useEffect(() => {
    if (activeReport !== "profit" && activeReport !== "overview") return;
    setProfitLoading(true);
    reportsApi.profit({ date_from: dateFrom, date_to: dateTo })
      .then((res) => setProfitData(res.data))
      .catch(() => setProfitData(null))
      .finally(() => setProfitLoading(false));
  }, [activeReport, dateFrom, dateTo]);

  // Stock tab — fetch once when first opened
  useEffect(() => {
    if (activeReport !== "stock" || stockData) return;
    setStockLoading(true);
    reportsApi.inventory()
      .then((res) => setStockData(res.data))
      .catch(() => setStockData(null))
      .finally(() => setStockLoading(false));
  }, [activeReport, stockData]);

  // Aging tab — fetch once when first opened
  useEffect(() => {
    if (activeReport !== "aging" || agingData) return;
    setAgingLoading(true);
    reportsApi.receivableAging()
      .then((res) => setAgingData(res.data))
      .catch(() => setAgingData(null))
      .finally(() => setAgingLoading(false));
  }, [activeReport, agingData]);

  // Day Book tab — refetch whenever the date or tab changes
  useEffect(() => {
    if (activeReport !== "daybook") return;
    setDayBookLoading(true);
    reportsApi.dayBook({ date: dayBookDate })
      .then((res) => setDayBookData(res.data))
      .catch(() => setDayBookData(null))
      .finally(() => setDayBookLoading(false));
  }, [activeReport, dayBookDate]);

  // Stock report — full per-product valuation list, fetched alongside the Stock tab's summary
  useEffect(() => {
    if (activeReport !== "stock" || stockReport) return;
    setStockReportLoading(true);
    reportsApi.stock()
      .then((res) => setStockReport(res.data))
      .catch(() => setStockReport(null))
      .finally(() => setStockReportLoading(false));
  }, [activeReport, stockReport]);

  // All Transactions tab — refetch on date range / type filter change
  useEffect(() => {
    if (activeReport !== "all-transactions") return;
    setAllTxLoading(true);
    reportsApi.allTransactions({ date_from: dateFrom, date_to: dateTo, type: allTxType || undefined })
      .then((res) => setAllTxData(res.data))
      .catch(() => setAllTxData(null))
      .finally(() => setAllTxLoading(false));
  }, [activeReport, dateFrom, dateTo, allTxType]);

  // Party Statement tab — load party list once when first opened
  useEffect(() => {
    if (activeReport !== "party-statement" || partyList.length || partyListLoading) return;
    setPartyListLoading(true);
    partiesApi.list()
      .then((res) => setPartyList(res.data.results ?? res.data))
      .catch(() => setPartyList([]))
      .finally(() => setPartyListLoading(false));
  }, [activeReport, partyList.length, partyListLoading]);

  // Party Statement tab — load ledger whenever a party is selected
  useEffect(() => {
    if (!selectedParty) { setPartyLedger(null); return; }
    setPartyLedgerLoading(true);
    partiesApi.ledger(selectedParty.id)
      .then((res) => setPartyLedger(res.data))
      .catch(() => setPartyLedger(null))
      .finally(() => setPartyLedgerLoading(false));
  }, [selectedParty]);

  // Cash In Hand tab — refetch on date range change
  useEffect(() => {
    if (activeReport !== "cash-in-hand") return;
    setCashHandLoading(true);
    reportsApi.cashInHand({ date_from: dateFrom, date_to: dateTo })
      .then((res) => setCashHandData(res.data))
      .catch(() => setCashHandData(null))
      .finally(() => setCashHandLoading(false));
  }, [activeReport, dateFrom, dateTo]);

  // Bank Statement tab — load account list once when first opened
  useEffect(() => {
    if (activeReport !== "bank-statement" || bankAccounts.length || bankAccountsLoading) return;
    setBankAccountsLoading(true);
    reportsApi.bankStatement()
      .then((res) => setBankAccounts(res.data.accounts ?? []))
      .catch(() => setBankAccounts([]))
      .finally(() => setBankAccountsLoading(false));
  }, [activeReport, bankAccounts.length, bankAccountsLoading]);

  // Bank Statement tab — load statement whenever an account is selected (or date range changes)
  useEffect(() => {
    if (!selectedAccount) { setBankStatement(null); return; }
    setBankStatementLoading(true);
    reportsApi.bankStatement({ account: selectedAccount.id, date_from: dateFrom, date_to: dateTo })
      .then((res) => setBankStatement(res.data))
      .catch(() => setBankStatement(null))
      .finally(() => setBankStatementLoading(false));
  }, [selectedAccount, dateFrom, dateTo]);

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
  // Same figure as the Profit & Loss tab (backend net_profit = revenue − returns
  // − COGS − expenses) — previously this card computed sales − expenses locally,
  // which ignored cost of goods sold and showed a different "Net Profit" than P&L.
  const netProfit = profitData ? profitData.net_profit : (totalSales - totalExp);

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

  const exportStockReport = () => exportCSV(
    ["Product", "Category", "Unit", "Stock Qty", "Purchase Price", "Sale Price", "Stock Value"],
    (stockReport?.items || []).map(p => [p.name, p.category, p.unit, p.stock_quantity, p.purchase_price, p.sale_price, p.stock_value]),
    `stock_report.csv`
  );

  const exportAllTransactions = () => exportCSV(
    ["Date", "Type", "Ref", "Party", "Amount", "Paid", "Due", "Method"],
    (allTxData?.entries || []).map(e => [e.date, e.type, e.ref, e.party, e.amount, e.paid, e.due, e.method]),
    `all_transactions_${dateFrom}_${dateTo}.csv`
  );

  const exportCashInHand = () => exportCSV(
    ["Date", "Type", "Ref", "Party", "In", "Out", "Balance"],
    (cashHandData?.entries || []).map(e => [e.date, e.type, e.ref, e.party, e.debit, e.credit, e.balance]),
    `cash_in_hand_${dateFrom}_${dateTo}.csv`
  );

  const exportBankStatement = () => exportCSV(
    ["Date", "Type", "Description", "Reference", "Debit", "Credit", "Balance"],
    (bankStatement?.entries || []).map(e => [e.date, e.type, e.description, e.reference, e.debit, e.credit, e.balance]),
    `bank_statement_${selectedAccount?.account_name || ""}_${dateFrom}_${dateTo}.csv`
  );

  const exportPartyStatement = () => exportCSV(
    ["Date", "Type", "Ref", "Debit", "Credit", "Balance", "Note"],
    (partyLedger?.entries || []).map(e => [e.date, e.type, e.ref, e.debit, e.credit, e.balance, e.note]),
    `party_statement_${selectedParty?.name || ""}.csv`
  );

  const handlePrint = () => {
    document.body.classList.add("print-mode");
    window.print();
    setTimeout(() => document.body.classList.remove("print-mode"), 1000);
  };

  const TABS = [
    { key: "overview", label: "Overview" },
    { key: "profit", label: "Profit & Loss" },
    { key: "stock", label: "Stock" },
    { key: "aging", label: "Aging" },
    { key: "sales", label: "Sales Detail" },
    { key: "expenses", label: "Expenses" },
    { key: "purchases", label: "Purchases" },
    { key: "daybook", label: "Day Book" },
    { key: "all-transactions", label: "All Transactions" },
    { key: "party-statement", label: "Party Statement" },
    { key: "cash-in-hand", label: "Cash In Hand" },
    { key: "bank-statement", label: "Bank Statement" },
  ];

  /* ── Popular Reports (quick-access tiles) ── */
  const POPULAR_REPORTS = [
    { key: "stock", label: "Stock Report", desc: "Product-wise stock valuation", icon: Boxes },
    { key: "sales", label: "Sales Report", desc: "Detailed invoice list", icon: TrendingUp },
    { key: "daybook", label: "Day Book", desc: "Daily cash register", icon: BookOpen },
    { key: "all-transactions", label: "All Transaction Report", desc: "Every transaction, one feed", icon: ListChecks },
    { key: "profit", label: "Profit & Loss Report", desc: "Revenue, COGS, net profit", icon: DollarSign },
    { key: "party-statement", label: "Party Statement", desc: "Per-party running ledger", icon: Users },
    { key: "cash-in-hand", label: "Cash In Hand Statement", desc: "Running cash balance", icon: Wallet },
    { key: "bank-statement", label: "Bank Statement", desc: "Per-account running balance", icon: Landmark },
  ];

  /* ── Browse All Reports (categories) ── */
  const REPORT_CATEGORIES = [
    { label: "Transaction Report", items: ["all-transactions", "sales", "purchases", "daybook"] },
    { label: "Parties Report", items: ["party-statement", "aging"] },
    { label: "Inventory Report", items: ["stock"] },
    { label: "Income & Expenses Report", items: ["profit", "expenses"] },
    { label: "Business Status Report", items: ["overview", "cash-in-hand"] },
  ];
  const [openCategory, setOpenCategory] = useState(null);

  const goToReport = (key) => {
    setActiveReport(key);
    requestAnimationFrame(() => {
      document.getElementById("report-content")?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  };

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

      {/* Popular Reports */}
      <div className="mb-5">
        <h2 className="mb-3 text-sm font-semibold text-white">Popular Reports</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {POPULAR_REPORTS.map(({ key, label, desc, icon: Icon }) => (
            <button key={key} onClick={() => goToReport(key)}
              className={`flex flex-col items-start gap-2 rounded-xl border p-4 text-left transition ${
                activeReport === key ? "border-orange-500 bg-orange-500/10" : "border-navy-800 bg-navy-900 hover:border-navy-700"
              }`}>
              <div className={`flex h-9 w-9 items-center justify-center rounded-lg ${activeReport === key ? "bg-orange-500/20" : "bg-navy-800"}`}>
                <Icon className={`h-4.5 w-4.5 ${activeReport === key ? "text-orange-400" : "text-navy-400"}`} />
              </div>
              <p className="text-sm font-semibold text-white">{label}</p>
              <p className="text-xs text-navy-500">{desc}</p>
            </button>
          ))}
        </div>
      </div>

      {/* Browse All Reports */}
      <div className="mb-5">
        <h2 className="mb-3 text-sm font-semibold text-white">Browse All Reports</h2>
        <div className="space-y-2">
          {REPORT_CATEGORIES.map((cat) => {
            const isOpen = openCategory === cat.label;
            return (
              <div key={cat.label} className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                <button
                  onClick={() => setOpenCategory(isOpen ? null : cat.label)}
                  className="flex w-full items-center justify-between px-4 py-3 text-left"
                >
                  <span className="text-sm font-semibold text-white">{cat.label}</span>
                  <ChevronRight className={`h-4 w-4 text-navy-400 transition-transform ${isOpen ? "rotate-90" : ""}`} />
                </button>
                {isOpen && (
                  <div className="flex flex-wrap gap-2 border-t border-navy-800 px-4 py-3">
                    {cat.items.map((key) => {
                      const tab = TABS.find(t => t.key === key);
                      if (!tab) return null;
                      return (
                        <button key={key} onClick={() => goToReport(key)}
                          className={`rounded-lg px-3 py-1.5 text-xs font-medium transition ${
                            activeReport === key ? "bg-orange-500 text-white" : "bg-navy-800 text-navy-300 hover:bg-navy-700 hover:text-white"
                          }`}>
                          {tab.label}
                        </button>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div id="report-content" />

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
          <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
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
                <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                  <div className="col-span-1">#</div>
                  <div className="col-span-6">Product</div>
                  <div className="col-span-2 text-right">Qty Sold</div>
                  <div className="col-span-3 text-right">Revenue</div>
                </div>
                {topProducts.map((p, i) => (
                  <div key={p.name} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 transition text-sm min-w-160">
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

      {/* Profit & Loss Tab (server-computed, includes COGS) */}
      {activeReport === "profit" && (
        <div className="space-y-5">
          {profitLoading ? (
            <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div>
          ) : !profitData ? (
            <div className="rounded-xl border border-navy-800 bg-navy-900 py-10 text-center text-sm text-navy-400">
              Could not load profit &amp; loss data
            </div>
          ) : (
            <>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
                {[
                  { label: "Revenue", value: profitData.revenue, color: "orange" },
                  { label: "COGS", value: profitData.cogs, color: "red" },
                  { label: "Gross Profit", value: profitData.gross_profit, color: "blue" },
                  { label: "Expenses", value: profitData.expenses, color: "red" },
                  { label: "Net Profit", value: profitData.net_profit, color: profitData.net_profit >= 0 ? "green" : "red" },
                ].map(({ label, value, color }) => (
                  <div key={label} className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                    <p className="text-xs text-navy-500">{label}</p>
                    <p className={`mt-1 text-lg font-bold text-${color}-400`}>
                      {maskAmount(value, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                    </p>
                  </div>
                ))}
              </div>
              <div className="grid grid-cols-2 gap-3 sm:w-1/2">
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Gross Margin</p>
                  <p className="mt-1 text-lg font-bold text-white">{profitData.gross_margin_pct}%</p>
                </div>
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Net Margin</p>
                  <p className="mt-1 text-lg font-bold text-white">{profitData.net_margin_pct}%</p>
                </div>
              </div>
              <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                <h3 className="mb-4 text-sm font-semibold text-white">Monthly Trend (6 months)</h3>
                <ResponsiveContainer width="100%" height={220}>
                  <BarChart
                    data={(profitData.monthly || []).map(m => ({ ...m, name: MONTHS[m.month - 1] || `M${m.month}` }))}
                    margin={{ top: 0, right: 8, left: 0, bottom: 0 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" stroke="#1e2a3b" />
                    <XAxis dataKey="name" tick={{ fill: "#64748b", fontSize: 11 }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fill: "#64748b", fontSize: 10 }} axisLine={false} tickLine={false} width={55}
                      tickFormatter={v => `${(v / 1000).toFixed(0)}k`} />
                    <Tooltip content={<CustomTooltip />} />
                    <Legend wrapperStyle={{ fontSize: "11px", paddingTop: "8px" }} />
                    <Bar dataKey="revenue" name="Revenue" fill="#f97316" radius={[3, 3, 0, 0]} />
                    <Bar dataKey="expenses" name="Expenses" fill="#ef4444" radius={[3, 3, 0, 0]} />
                    <Bar dataKey="net_profit" name="Net Profit" fill="#22c55e" radius={[3, 3, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </>
          )}
        </div>
      )}

      {/* Stock Tab (server-computed inventory report) */}
      {activeReport === "stock" && (
        <div className="space-y-5">
          {stockLoading ? (
            <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div>
          ) : !stockData ? (
            <div className="rounded-xl border border-navy-800 bg-navy-900 py-10 text-center text-sm text-navy-400">
              Could not load stock report
            </div>
          ) : (
            <>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                {[
                  { label: "Total Products", value: stockData.total_products, isCount: true },
                  { label: "Low Stock", value: stockData.low_stock_count, isCount: true, color: "yellow" },
                  { label: "Out of Stock", value: stockData.out_of_stock_count, isCount: true, color: "red" },
                  { label: "Stock Value", value: stockData.stock_value, color: "blue" },
                ].map(({ label, value, isCount, color = "white" }) => (
                  <div key={label} className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                    <p className="text-xs text-navy-500">{label}</p>
                    <p className={`mt-1 text-lg font-bold text-${color}-400`}>
                      {isCount ? (value ?? 0).toLocaleString() : maskAmount(value, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                    </p>
                  </div>
                ))}
              </div>
              <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                <div className="px-4 py-3 border-b border-navy-800">
                  <h3 className="text-sm font-semibold text-white">Low Stock Items ({stockData.low_stock_items?.length || 0})</h3>
                </div>
                {(stockData.low_stock_items || []).length === 0 ? (
                  <div className="py-10 text-center text-sm text-navy-400">No low-stock items</div>
                ) : (
                  <>
                    <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                      <div className="col-span-5">Product</div>
                      <div className="col-span-3 text-right">Stock Qty</div>
                      <div className="col-span-2 text-right">Min Level</div>
                      <div className="col-span-2 text-right">Sale Price</div>
                    </div>
                    {stockData.low_stock_items.map(p => (
                      <div key={p.id} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
                        <div className="col-span-5 text-white truncate">{p.name}</div>
                        <div className="col-span-3 text-right text-yellow-400 font-semibold">{p.stock_quantity}</div>
                        <div className="col-span-2 text-right text-navy-400">{p.low_stock_threshold}</div>
                        <div className="col-span-2 text-right text-navy-400">Rs. {parseFloat(p.selling_price || p.sale_price || 0).toLocaleString()}</div>
                      </div>
                    ))}
                  </>
                )}
              </div>

              {/* Full per-product stock valuation */}
              <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
                  <h3 className="text-sm font-semibold text-white">All Products ({stockReport?.items?.length || 0})</h3>
                  <button onClick={exportStockReport}
                    className="flex items-center gap-1.5 rounded-lg border border-green-500/40 bg-green-500/10 px-3 py-1.5 text-xs font-semibold text-green-400 hover:bg-green-500/20 transition">
                    <Download className="h-3.5 w-3.5" /> Download CSV
                  </button>
                </div>
                {stockReportLoading ? (
                  <div className="py-10 text-center text-sm text-navy-400">Loading…</div>
                ) : !stockReport || stockReport.items.length === 0 ? (
                  <div className="py-10 text-center text-sm text-navy-400">No products found</div>
                ) : (
                  <>
                    <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                      <div className="col-span-4">Product</div>
                      <div className="col-span-2">Category</div>
                      <div className="col-span-2 text-right">Qty</div>
                      <div className="col-span-2 text-right">Purchase Price</div>
                      <div className="col-span-2 text-right">Stock Value</div>
                    </div>
                    {stockReport.items.map(p => (
                      <div key={p.id} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
                        <div className="col-span-4 text-white truncate">
                          {p.name}
                          {p.is_low_stock && <span className="ml-1.5 rounded bg-yellow-500/10 px-1.5 py-0.5 text-[10px] text-yellow-400">Low</span>}
                        </div>
                        <div className="col-span-2 text-navy-400 truncate">{p.category || "—"}</div>
                        <div className="col-span-2 text-right text-navy-300">{p.stock_quantity} {p.unit}</div>
                        <div className="col-span-2 text-right text-navy-400">Rs. {p.purchase_price.toLocaleString()}</div>
                        <div className="col-span-2 text-right text-blue-400 font-semibold">Rs. {p.stock_value.toLocaleString()}</div>
                      </div>
                    ))}
                    <div className="border-t border-navy-800 bg-navy-900/80 px-4 py-3 grid grid-cols-12 gap-2 text-xs font-bold">
                      <div className="col-span-8 text-navy-400">Total ({stockReport.total_products} products, {stockReport.total_quantity} units)</div>
                      <div className="col-span-4 text-right text-blue-400">Rs. {Math.round(stockReport.total_stock_value).toLocaleString()}</div>
                    </div>
                  </>
                )}
              </div>
            </>
          )}
        </div>
      )}

      {/* Aging Tab (receivable aging buckets + top debtors) */}
      {activeReport === "aging" && (
        <div className="space-y-5">
          {agingLoading ? (
            <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div>
          ) : !agingData ? (
            <div className="rounded-xl border border-navy-800 bg-navy-900 py-10 text-center text-sm text-navy-400">
              Could not load receivable aging data
            </div>
          ) : (
            <>
              <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                <p className="text-xs text-navy-500">Total Receivable</p>
                <p className="mt-1 text-2xl font-bold text-orange-400">
                  {maskAmount(agingData.total_receivable, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                </p>
              </div>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                {[agingData.current, agingData.days31_60, agingData.days61_90, agingData.over90].map((bucket) => (
                  <div key={bucket.label} className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                    <p className="text-xs text-navy-500">{bucket.label}</p>
                    <p className="mt-1 text-lg font-bold text-white">
                      {maskAmount(bucket.total, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                    </p>
                    <p className="text-xs text-navy-500 mt-1">{bucket.count} invoice{bucket.count === 1 ? "" : "s"}</p>
                  </div>
                ))}
              </div>
              <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                <div className="px-4 py-3 border-b border-navy-800">
                  <h3 className="text-sm font-semibold text-white">Top Overdue Customers</h3>
                </div>
                {(agingData.top_debtors || []).length === 0 ? (
                  <div className="py-10 text-center text-sm text-navy-400">No outstanding receivables</div>
                ) : (
                  <>
                    <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                      <div className="col-span-6">Customer</div>
                      <div className="col-span-3 text-right">Invoices</div>
                      <div className="col-span-3 text-right">Due</div>
                    </div>
                    {agingData.top_debtors.map((d, i) => (
                      <div key={d.customer_id ?? i} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
                        <div className="col-span-6 text-white truncate">{d.customer__name || "Walk-in"}</div>
                        <div className="col-span-3 text-right text-navy-400">{d.invoice_count}</div>
                        <div className="col-span-3 text-right text-red-400 font-semibold">Rs. {parseFloat(d.total_due || 0).toLocaleString()}</div>
                      </div>
                    ))}
                  </>
                )}
              </div>
            </>
          )}
        </div>
      )}

      {/* Sales Detail Tab */}
      {activeReport === "sales" && (
        <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
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
              <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                <div className="col-span-2">Invoice</div>
                <div className="col-span-2">Date</div>
                <div className="col-span-3">Customer</div>
                <div className="col-span-2 text-right">Total</div>
                <div className="col-span-2 text-right">Paid</div>
                <div className="col-span-1 text-right">Due</div>
              </div>
              {filteredSales.map(s => (
                <div key={s.id} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
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
        <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
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
              <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                <div className="col-span-2">Date</div>
                <div className="col-span-3">Category</div>
                <div className="col-span-4">Description</div>
                <div className="col-span-2 text-right">Amount</div>
                <div className="col-span-1 text-right">Method</div>
              </div>
              {filteredExp.map(e => (
                <div key={e.id} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
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
        <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
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
              <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                <div className="col-span-2">Bill No</div>
                <div className="col-span-2">Date</div>
                <div className="col-span-3">Supplier</div>
                <div className="col-span-2 text-right">Total</div>
                <div className="col-span-2 text-right">Paid</div>
                <div className="col-span-1 text-right">Due</div>
              </div>
              {filteredPurchases.map(p => (
                <div key={p.id} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
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

      {/* Day Book Tab — daily transaction register */}
      {activeReport === "daybook" && (
        <div className="space-y-5">
          <div className="flex items-center gap-3 rounded-2xl border border-navy-800 bg-navy-900 px-4 py-3">
            <Calendar className="h-4 w-4 text-navy-400 shrink-0" />
            <p className="text-xs font-semibold text-navy-400 shrink-0">Date:</p>
            <input type="date" value={dayBookDate} onChange={e => setDayBookDate(e.target.value)}
              className="rounded-lg border border-navy-700 bg-navy-800 px-3 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none" />
          </div>

          {dayBookLoading ? (
            <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div>
          ) : !dayBookData ? (
            <div className="rounded-xl border border-navy-800 bg-navy-900 py-10 text-center text-sm text-navy-400">
              Could not load day book data
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Cash In</p>
                  <p className="mt-1 text-lg font-bold text-green-400">
                    {maskAmount(dayBookData.total_in, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Cash Out</p>
                  <p className="mt-1 text-lg font-bold text-red-400">
                    {maskAmount(dayBookData.total_out, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Net Cash</p>
                  <p className={`mt-1 text-lg font-bold ${dayBookData.net_cash >= 0 ? "text-white" : "text-red-400"}`}>
                    {maskAmount(dayBookData.net_cash, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
              </div>

              <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                <div className="px-4 py-3 border-b border-navy-800">
                  <h3 className="text-sm font-semibold text-white">Entries ({dayBookData.entries?.length || 0})</h3>
                </div>
                {(dayBookData.entries || []).length === 0 ? (
                  <div className="py-10 text-center text-sm text-navy-400">No transactions on this date</div>
                ) : (
                  <>
                    <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                      <div className="col-span-2">Type</div>
                      <div className="col-span-2">Ref</div>
                      <div className="col-span-3">Party</div>
                      <div className="col-span-2 text-right">In</div>
                      <div className="col-span-2 text-right">Out</div>
                      <div className="col-span-1">Method</div>
                    </div>
                    {dayBookData.entries.map((e, i) => (
                      <div key={i} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
                        <div className="col-span-2 text-navy-300">{e.type}</div>
                        <div className="col-span-2 text-navy-400 truncate">{e.ref}</div>
                        <div className="col-span-3 text-white truncate">{e.party}</div>
                        <div className="col-span-2 text-right text-green-400">{e.debit ? `Rs. ${e.debit.toLocaleString()}` : "—"}</div>
                        <div className="col-span-2 text-right text-red-400">{e.credit ? `Rs. ${e.credit.toLocaleString()}` : "—"}</div>
                        <div className="col-span-1 text-navy-500">{e.method}</div>
                      </div>
                    ))}
                  </>
                )}
              </div>
            </>
          )}
        </div>
      )}

      {/* All Transactions Tab — combined feed across the date range */}
      {activeReport === "all-transactions" && (
        <div className="space-y-5">
          <div className="flex flex-wrap items-center gap-2">
            {[
              { key: "", label: "All" },
              { key: "SALE", label: "Sales" },
              { key: "PURCHASE", label: "Purchases" },
              { key: "EXPENSE", label: "Expenses" },
              { key: "PAYMENT", label: "Payments" },
              { key: "BANK", label: "Bank" },
            ].map(f => (
              <button key={f.key} onClick={() => setAllTxType(f.key)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
                  allTxType === f.key ? "bg-orange-500 text-white" : "bg-navy-800 text-navy-300 hover:bg-navy-700 hover:text-white"
                }`}>
                {f.label}
              </button>
            ))}
          </div>

          {allTxLoading ? (
            <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div>
          ) : !allTxData ? (
            <div className="rounded-xl border border-navy-800 bg-navy-900 py-10 text-center text-sm text-navy-400">
              Could not load transaction data
            </div>
          ) : (
            <>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Total Sales</p>
                  <p className="mt-1 text-lg font-bold text-orange-400">
                    {maskAmount(allTxData.summary.total_sales, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Total Purchases</p>
                  <p className="mt-1 text-lg font-bold text-blue-400">
                    {maskAmount(allTxData.summary.total_purchases, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Total Expenses</p>
                  <p className="mt-1 text-lg font-bold text-red-400">
                    {maskAmount(allTxData.summary.total_expenses, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
              </div>

              <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
                  <h3 className="text-sm font-semibold text-white">Transactions ({allTxData.count})</h3>
                  <button onClick={exportAllTransactions}
                    className="flex items-center gap-1.5 rounded-lg border border-green-500/40 bg-green-500/10 px-3 py-1.5 text-xs font-semibold text-green-400 hover:bg-green-500/20 transition">
                    <Download className="h-3.5 w-3.5" /> Download CSV
                  </button>
                </div>
                {allTxData.entries.length === 0 ? (
                  <div className="py-10 text-center text-sm text-navy-400">No transactions in selected range</div>
                ) : (
                  <>
                    <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                      <div className="col-span-2">Date</div>
                      <div className="col-span-2">Type</div>
                      <div className="col-span-2">Ref</div>
                      <div className="col-span-3">Party</div>
                      <div className="col-span-2 text-right">Amount</div>
                      <div className="col-span-1 text-right">Due</div>
                    </div>
                    {allTxData.entries.map((e, i) => (
                      <div key={i} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
                        <div className="col-span-2 text-navy-400">{e.date}</div>
                        <div className="col-span-2 text-navy-300">{e.type}</div>
                        <div className="col-span-2 text-navy-400 truncate">{e.ref}</div>
                        <div className="col-span-3 text-white truncate">{e.party}</div>
                        <div className="col-span-2 text-right text-white font-semibold">Rs. {e.amount.toLocaleString()}</div>
                        <div className="col-span-1 text-right text-red-400">{e.due ? `Rs. ${e.due.toLocaleString()}` : "—"}</div>
                      </div>
                    ))}
                  </>
                )}
              </div>
            </>
          )}
        </div>
      )}

      {/* Party Statement Tab — pick a party, view running ledger */}
      {activeReport === "party-statement" && (
        <div className="space-y-5">
          {!selectedParty ? (
            <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
              <div className="flex items-center gap-2 border-b border-navy-800 px-4 py-3">
                <Search className="h-4 w-4 text-navy-500" />
                <input value={partySearch} onChange={e => setPartySearch(e.target.value)}
                  placeholder="Search parties…"
                  className="w-full bg-transparent text-sm text-white outline-none placeholder:text-navy-500" />
              </div>
              {partyListLoading ? (
                <div className="py-10 text-center text-sm text-navy-400">Loading…</div>
              ) : (
                <>
                  {partyList
                    .filter(p => p.name.toLowerCase().includes(partySearch.toLowerCase()))
                    .map(p => {
                      const balance = parseFloat(p.balance ?? p.opening_balance ?? 0);
                      return (
                        <button key={p.id} onClick={() => setSelectedParty(p)}
                          className="flex w-full items-center justify-between px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-left transition">
                          <div>
                            <p className="text-sm font-medium text-white">{p.name}</p>
                            <p className="text-xs text-navy-500">{p.party_type}</p>
                          </div>
                          <p className={`text-sm font-semibold ${balance > 0 ? "text-red-400" : balance < 0 ? "text-green-400" : "text-navy-400"}`}>
                            {maskAmount(Math.abs(balance), v => `Rs. ${v.toLocaleString()}`)}
                          </p>
                        </button>
                      );
                    })}
                  {partyList.length === 0 && (
                    <div className="py-10 text-center text-sm text-navy-400">No parties found</div>
                  )}
                </>
              )}
            </div>
          ) : (
            <>
              <button onClick={() => setSelectedParty(null)}
                className="flex items-center gap-1.5 text-xs font-semibold text-navy-400 hover:text-white transition">
                <ArrowLeft className="h-3.5 w-3.5" /> Back to parties
              </button>

              {partyLedgerLoading ? (
                <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div>
              ) : !partyLedger ? (
                <div className="rounded-xl border border-navy-800 bg-navy-900 py-10 text-center text-sm text-navy-400">
                  Could not load party statement
                </div>
              ) : (
                <>
                  <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                    <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                      <p className="text-xs text-navy-500">Total Debit</p>
                      <p className="mt-1 text-lg font-bold text-red-400">
                        {maskAmount(partyLedger.total_debit, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                      </p>
                    </div>
                    <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                      <p className="text-xs text-navy-500">Total Credit</p>
                      <p className="mt-1 text-lg font-bold text-green-400">
                        {maskAmount(partyLedger.total_credit, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                      </p>
                    </div>
                    <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                      <p className="text-xs text-navy-500">Closing Balance</p>
                      <p className={`mt-1 text-lg font-bold ${partyLedger.closing_balance > 0 ? "text-red-400" : partyLedger.closing_balance < 0 ? "text-green-400" : "text-white"}`}>
                        {maskAmount(Math.abs(partyLedger.closing_balance), v => `Rs. ${Math.round(v).toLocaleString()}`)}
                      </p>
                    </div>
                  </div>

                  <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                    <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
                      <h3 className="text-sm font-semibold text-white">{selectedParty.name} — Statement</h3>
                      <button onClick={exportPartyStatement}
                        className="flex items-center gap-1.5 rounded-lg border border-green-500/40 bg-green-500/10 px-3 py-1.5 text-xs font-semibold text-green-400 hover:bg-green-500/20 transition">
                        <Download className="h-3.5 w-3.5" /> Download CSV
                      </button>
                    </div>
                    {partyLedger.entries.length === 0 ? (
                      <div className="py-10 text-center text-sm text-navy-400">No transactions yet</div>
                    ) : (
                      <>
                        <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                          <div className="col-span-2">Date</div>
                          <div className="col-span-2">Type</div>
                          <div className="col-span-3">Ref</div>
                          <div className="col-span-2 text-right">Debit</div>
                          <div className="col-span-2 text-right">Credit</div>
                          <div className="col-span-1 text-right">Balance</div>
                        </div>
                        {partyLedger.entries.map((e, i) => (
                          <div key={i} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
                            <div className="col-span-2 text-navy-400">{e.date}</div>
                            <div className="col-span-2 text-navy-300">{e.type}</div>
                            <div className="col-span-3 text-navy-400 truncate">{e.ref}{e.note ? ` · ${e.note}` : ""}</div>
                            <div className="col-span-2 text-right text-red-400">{e.debit ? `Rs. ${e.debit.toLocaleString()}` : "—"}</div>
                            <div className="col-span-2 text-right text-green-400">{e.credit ? `Rs. ${e.credit.toLocaleString()}` : "—"}</div>
                            <div className="col-span-1 text-right text-white font-semibold">Rs. {e.balance.toLocaleString()}</div>
                          </div>
                        ))}
                      </>
                    )}
                  </div>
                </>
              )}
            </>
          )}
        </div>
      )}

      {/* Cash In Hand Tab — running cash balance over the date range */}
      {activeReport === "cash-in-hand" && (
        <div className="space-y-5">
          {cashHandLoading ? (
            <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div>
          ) : !cashHandData ? (
            <div className="rounded-xl border border-navy-800 bg-navy-900 py-10 text-center text-sm text-navy-400">
              Could not load cash in hand data
            </div>
          ) : (
            <>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Opening Balance</p>
                  <p className="mt-1 text-lg font-bold text-white">
                    {maskAmount(cashHandData.opening_balance, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Cash In</p>
                  <p className="mt-1 text-lg font-bold text-green-400">
                    {maskAmount(cashHandData.total_in, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Cash Out</p>
                  <p className="mt-1 text-lg font-bold text-red-400">
                    {maskAmount(cashHandData.total_out, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
                <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                  <p className="text-xs text-navy-500">Closing Balance</p>
                  <p className={`mt-1 text-lg font-bold ${cashHandData.closing_balance >= 0 ? "text-white" : "text-red-400"}`}>
                    {maskAmount(cashHandData.closing_balance, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                  </p>
                </div>
              </div>

              <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
                  <h3 className="text-sm font-semibold text-white">Entries ({cashHandData.entries?.length || 0})</h3>
                  <button onClick={exportCashInHand}
                    className="flex items-center gap-1.5 rounded-lg border border-green-500/40 bg-green-500/10 px-3 py-1.5 text-xs font-semibold text-green-400 hover:bg-green-500/20 transition">
                    <Download className="h-3.5 w-3.5" /> Download CSV
                  </button>
                </div>
                {(cashHandData.entries || []).length === 0 ? (
                  <div className="py-10 text-center text-sm text-navy-400">No cash transactions in selected range</div>
                ) : (
                  <>
                    <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                      <div className="col-span-2">Date</div>
                      <div className="col-span-2">Type</div>
                      <div className="col-span-3">Party</div>
                      <div className="col-span-2 text-right">In</div>
                      <div className="col-span-2 text-right">Out</div>
                      <div className="col-span-1 text-right">Balance</div>
                    </div>
                    {cashHandData.entries.map((e, i) => (
                      <div key={i} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
                        <div className="col-span-2 text-navy-400">{e.date}</div>
                        <div className="col-span-2 text-navy-300">{e.type}</div>
                        <div className="col-span-3 text-white truncate">{e.party}</div>
                        <div className="col-span-2 text-right text-green-400">{e.debit ? `Rs. ${e.debit.toLocaleString()}` : "—"}</div>
                        <div className="col-span-2 text-right text-red-400">{e.credit ? `Rs. ${e.credit.toLocaleString()}` : "—"}</div>
                        <div className="col-span-1 text-right text-white font-semibold">Rs. {e.balance.toLocaleString()}</div>
                      </div>
                    ))}
                  </>
                )}
              </div>
            </>
          )}
        </div>
      )}

      {/* Bank Statement Tab — pick an account, view running balance */}
      {activeReport === "bank-statement" && (
        <div className="space-y-5">
          {!selectedAccount ? (
            <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
              <div className="px-4 py-3 border-b border-navy-800">
                <h3 className="text-sm font-semibold text-white">Select an Account</h3>
              </div>
              {bankAccountsLoading ? (
                <div className="py-10 text-center text-sm text-navy-400">Loading…</div>
              ) : bankAccounts.length === 0 ? (
                <div className="py-10 text-center text-sm text-navy-400">No bank accounts found</div>
              ) : (
                bankAccounts.map(a => (
                  <button key={a.id} onClick={() => setSelectedAccount(a)}
                    className="flex w-full items-center justify-between px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-left transition">
                    <div className="flex items-center gap-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-navy-800">
                        <Landmark className="h-4 w-4 text-navy-400" />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-white">{a.account_name}</p>
                        <p className="text-xs text-navy-500">{a.bank_name || a.account_type}</p>
                      </div>
                    </div>
                    <p className="text-sm font-semibold text-white">
                      {maskAmount(a.balance, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                    </p>
                  </button>
                ))
              )}
            </div>
          ) : (
            <>
              <button onClick={() => setSelectedAccount(null)}
                className="flex items-center gap-1.5 text-xs font-semibold text-navy-400 hover:text-white transition">
                <ArrowLeft className="h-3.5 w-3.5" /> Back to accounts
              </button>

              {bankStatementLoading ? (
                <div className="flex h-48 items-center justify-center text-sm text-navy-400">Loading…</div>
              ) : !bankStatement ? (
                <div className="rounded-xl border border-navy-800 bg-navy-900 py-10 text-center text-sm text-navy-400">
                  Could not load bank statement
                </div>
              ) : (
                <>
                  <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                    <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                      <p className="text-xs text-navy-500">Opening Balance</p>
                      <p className="mt-1 text-lg font-bold text-white">
                        {maskAmount(bankStatement.opening_balance, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                      </p>
                    </div>
                    <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                      <p className="text-xs text-navy-500">Total Credit</p>
                      <p className="mt-1 text-lg font-bold text-green-400">
                        {maskAmount(bankStatement.total_credit, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                      </p>
                    </div>
                    <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                      <p className="text-xs text-navy-500">Total Debit</p>
                      <p className="mt-1 text-lg font-bold text-red-400">
                        {maskAmount(bankStatement.total_debit, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                      </p>
                    </div>
                    <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
                      <p className="text-xs text-navy-500">Closing Balance</p>
                      <p className={`mt-1 text-lg font-bold ${bankStatement.closing_balance >= 0 ? "text-white" : "text-red-400"}`}>
                        {maskAmount(bankStatement.closing_balance, v => `Rs. ${Math.round(v).toLocaleString()}`)}
                      </p>
                    </div>
                  </div>

                  <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
                    <div className="flex items-center justify-between px-4 py-3 border-b border-navy-800">
                      <h3 className="text-sm font-semibold text-white">{bankStatement.account.account_name} — Statement</h3>
                      <button onClick={exportBankStatement}
                        className="flex items-center gap-1.5 rounded-lg border border-green-500/40 bg-green-500/10 px-3 py-1.5 text-xs font-semibold text-green-400 hover:bg-green-500/20 transition">
                        <Download className="h-3.5 w-3.5" /> Download CSV
                      </button>
                    </div>
                    {bankStatement.entries.length === 0 ? (
                      <div className="py-10 text-center text-sm text-navy-400">No transactions in selected range</div>
                    ) : (
                      <>
                        <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-semibold text-navy-500 border-b border-navy-800/50 min-w-160">
                          <div className="col-span-2">Date</div>
                          <div className="col-span-2">Type</div>
                          <div className="col-span-3">Description</div>
                          <div className="col-span-2 text-right">Debit</div>
                          <div className="col-span-2 text-right">Credit</div>
                          <div className="col-span-1 text-right">Balance</div>
                        </div>
                        {bankStatement.entries.map((e, i) => (
                          <div key={i} className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/30 hover:bg-navy-800/20 text-xs min-w-160">
                            <div className="col-span-2 text-navy-400">{e.date}</div>
                            <div className="col-span-2 text-navy-300">{e.type}</div>
                            <div className="col-span-3 text-navy-400 truncate">{e.description || e.reference || "—"}</div>
                            <div className="col-span-2 text-right text-red-400">{e.debit ? `Rs. ${e.debit.toLocaleString()}` : "—"}</div>
                            <div className="col-span-2 text-right text-green-400">{e.credit ? `Rs. ${e.credit.toLocaleString()}` : "—"}</div>
                            <div className="col-span-1 text-right text-white font-semibold">Rs. {e.balance.toLocaleString()}</div>
                          </div>
                        ))}
                      </>
                    )}
                  </div>
                </>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}
