import { useState, useEffect, useRef } from "react";
import { useSearchParams } from "react-router-dom";
import { Plus, Search, Edit2, Trash2, X, AlertCircle, Upload, Image, Eye } from "lucide-react";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell
} from "recharts";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import { expenses as expensesApi } from "../api/index.js";
import { adToBS, formatBS } from "../utils/nepaliDate";
import { useEscToClose } from "../hooks/useEscToClose";
import { todayStr, monthStr } from "../utils/dates";

const today = () => todayStr();

function formatDate(dateStr, dateMode, language) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  if (dateMode === "BS") return formatBS(adToBS(d), language);
  return d.toLocaleDateString("en-GB");
}

const CATEGORIES = ["Daily", "Purchase", "Utility", "Staff", "Other"];
const PAYMENT_METHODS = [
  { value: "CASH", label: "Cash" },
  { value: "BANK", label: "Bank" },
  { value: "ESEWA", label: "eSewa" },
  { value: "KHALTI", label: "Khalti" },
];
const PAYMENT_METHOD_LABELS = PAYMENT_METHODS.reduce((acc, m) => ({ ...acc, [m.value]: m.label }), {});

const CAT_COLORS = {
  Daily: "bg-blue-500/10 text-blue-400",
  Purchase: "bg-orange-500/10 text-orange-400",
  Utility: "bg-yellow-500/10 text-yellow-400",
  Staff: "bg-green-500/10 text-green-400",
  Other: "bg-navy-700/50 text-navy-400",
};

const CHART_COLORS = ["#f97316", "#3b82f6", "#22c55e", "#eab308", "#8b5cf6"];

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/* ─── Expense Modal ─── */
function ExpenseModal({ onClose, onSaved, editData, categories }) {
  useEscToClose(onClose);

  const [form, setForm] = useState(editData ? {
    amount: editData.amount || "",
    date: editData.date || today(),
    category: editData.category || categories[0]?.id || "",
    description: editData.description || editData.notes || "",
    payment_method: editData.payment_method || "CASH",
  } : {
    amount: "",
    date: today(),
    category: categories[0]?.id || "",
    description: "",
    payment_method: "CASH",
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [receiptImage, setReceiptImage] = useState(null);
  const [receiptPreview, setReceiptPreview] = useState(editData?.receipt_image_url || null);
  const receiptRef = useRef(null);

  const handleReceiptChange = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setReceiptImage(file);
    setReceiptPreview(URL.createObjectURL(file));
  };

  const handleSubmit = async () => {
    setError("");
    if (!form.amount || parseFloat(form.amount) <= 0) { setError("Amount is required."); return; }
    setSaving(true);
    try {
      // category is optional on the backend — omit it entirely when unset
      // instead of sending an empty string, which fails FK validation.
      const fields = { ...form };
      if (!fields.category) delete fields.category;
      let payload;
      if (receiptImage) {
        payload = new FormData();
        Object.entries(fields).forEach(([k, v]) => payload.append(k, v));
        payload.append("receipt_image", receiptImage);
      } else {
        payload = fields;
      }
      if (editData?.id) {
        await expensesApi.update(editData.id, payload);
      } else {
        await expensesApi.create(payload);
      }
      onSaved();
    } catch (e) {
      setError(e.response?.data?.detail || "Failed to save expense.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl">
        <div className="flex items-center justify-between border-b border-navy-800 p-5">
          <h2 className="text-lg font-bold text-white">{editData ? "Edit Expense" : "Add Expense"}</h2>
          <button onClick={onClose} className="text-navy-500 hover:text-white"><X size={20} /></button>
        </div>
        <div className="p-5 space-y-4">
          {error && (
            <div className="flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-sm text-red-400">
              <AlertCircle size={16} /> {error}
            </div>
          )}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Amount *</label>
              <input type="number" min="0" step="0.01"
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                placeholder="0.00"
                value={form.amount}
                onChange={e => setForm(f => ({ ...f, amount: e.target.value }))}
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Date *</label>
              <input type="date"
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
                value={form.date}
                onChange={e => setForm(f => ({ ...f, date: e.target.value }))}
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Category</label>
              <select
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
                value={form.category}
                onChange={e => setForm(f => ({ ...f, category: e.target.value }))}
              >
                {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Payment Method</label>
              <select
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
                value={form.payment_method}
                onChange={e => setForm(f => ({ ...f, payment_method: e.target.value }))}
              >
                {PAYMENT_METHODS.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
              </select>
            </div>
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Description</label>
            <textarea rows={3}
              className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none resize-none text-sm"
              placeholder="What was this expense for?"
              value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Receipt Image (optional)</label>
            <input ref={receiptRef} type="file" accept="image/*" className="hidden" onChange={handleReceiptChange} />
            {receiptPreview ? (
              <div className="relative inline-block">
                <img src={receiptPreview} alt="Receipt" className="h-24 w-auto rounded-lg border border-navy-700 object-cover" />
                <button
                  type="button"
                  onClick={() => { setReceiptImage(null); setReceiptPreview(null); if (receiptRef.current) receiptRef.current.value = ""; }}
                  className="absolute -right-2 -top-2 rounded-full bg-red-500 p-0.5 text-white hover:bg-red-600"
                >
                  <X className="h-3 w-3" />
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => receiptRef.current?.click()}
                className="flex items-center gap-2 rounded-lg border border-dashed border-navy-600 px-4 py-2.5 text-xs text-navy-400 hover:border-orange-500 hover:text-orange-400 transition"
              >
                <Upload className="h-4 w-4" /> Upload receipt photo
              </button>
            )}
          </div>
        </div>
        <div className="flex gap-3 justify-end border-t border-navy-800 p-5">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800">Cancel</button>
          <button disabled={saving} onClick={handleSubmit}
            className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50">
            {saving ? "Saving…" : editData ? "Update" : "Add Expense"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ─── Custom Tooltip for chart ─── */
function CustomTooltip({ active, payload, label }) {
  if (active && payload && payload.length) {
    return (
      <div className="rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm">
        <p className="font-semibold text-white mb-1">{label}</p>
        {payload.map((p, i) => (
          <p key={i} style={{ color: p.fill }}>Rs. {parseFloat(p.value).toLocaleString()}</p>
        ))}
      </div>
    );
  }
  return null;
}

/* ─── Main Page ─── */
export default function ExpensesPage() {
  const { t } = useTranslation();
  const { dateMode, language } = useAppSettings();
  const maskAmount = usePrivateAmount();

  const [list, setList] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [category, setCategory] = useState("All");
  const [search, setSearch] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [editItem, setEditItem] = useState(null);
  const [deleteItem, setDeleteItem] = useState(null);
  const [deleteError, setDeleteError] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [viewReceiptImage, setViewReceiptImage] = useState(null);
  const [searchParams, setSearchParams] = useSearchParams();

  // Alt+E (see useKeyboardShortcuts) lands here as ?action=add.
  useEffect(() => {
    if (searchParams.get("action") === "add") {
      setEditItem(null);
      setShowModal(true);
      setSearchParams((prev) => { prev.delete("action"); return prev; }, { replace: true });
    }
  }, [searchParams, setSearchParams]);

  const load = () => {
    setLoading(true);
    expensesApi.list({ page_size: 1000 })
      .then(r => setList(r.data.results ?? r.data))
      .catch(() => setList([]))
      .finally(() => setLoading(false));
  };

  const loadCategories = async () => {
    try {
      const r = await expensesApi.categories();
      let cats = r.data.results ?? r.data;
      if (!cats || cats.length === 0) {
        // Seed the standard categories on first use so the expense form has
        // real ExpenseCategory rows to reference (the backend `category`
        // field is an FK, not a free-text choice).
        const created = [];
        for (const name of CATEGORIES) {
          try {
            const res = await expensesApi.createCategory({ name, expense_type: name.toUpperCase() });
            created.push(res.data);
          } catch { /* ignore duplicates / race */ }
        }
        cats = created;
      }
      setCategories(cats);
    } catch {
      setCategories([]);
    }
  };

  useEffect(load, []);
  useEffect(() => { loadCategories(); }, []);

  // Stats
  const thisMonth = monthStr();
  const monthExpenses = list.filter(e => (e.date || "").startsWith(thisMonth));
  const totalThisMonth = monthExpenses.reduce((s, e) => s + parseFloat(e.amount || 0), 0);
  const totalAll = list.reduce((s, e) => s + parseFloat(e.amount || 0), 0);

  // Category totals
  const catTotals = CATEGORIES.map(c => ({
    category: c,
    amount: list.filter(e => e.category_name === c).reduce((s, e) => s + parseFloat(e.amount || 0), 0),
  }));

  // Monthly chart data (last 6 months)
  const monthlyData = Array.from({ length: 6 }, (_, i) => {
    const d = new Date();
    // Mid-month first: stepping months back from the 29th-31st would otherwise
    // overflow into the wrong month (e.g. 31 Mar - 1 month -> 3 Mar).
    d.setDate(15);
    d.setMonth(d.getMonth() - (5 - i));
    const key = monthStr(d);
    const total = list.filter(e => (e.date || "").startsWith(key)).reduce((s, e) => s + parseFloat(e.amount || 0), 0);
    return { month: MONTHS[d.getMonth()], amount: total };
  });

  // Filtered list
  const filtered = list.filter(e => {
    const matchCat = category === "All" || e.category_name === category;
    const q = search.toLowerCase();
    const matchSearch = !q ||
      (e.description || e.notes || "").toLowerCase().includes(q) ||
      (e.category_name || "").toLowerCase().includes(q);
    return matchCat && matchSearch;
  });

  return (
    <div>
      {/* Header */}
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">{t("expenses")}</h1>
          <p className="text-sm text-navy-500">Track and categorize business expenses</p>
        </div>
        <button onClick={() => { setEditItem(null); setShowModal(true); }}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600">
          <Plus size={16} /> Add Expense
        </button>
      </div>

      {/* Summary Cards */}
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">This Month</p>
          <p className="text-2xl font-bold text-white mt-1">{maskAmount(totalThisMonth, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">Total</p>
          <p className="text-2xl font-bold text-orange-400 mt-1">{maskAmount(totalAll, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
        </div>
        {catTotals.slice(0, 2).map(c => (
          <div key={c.category} className="rounded-xl border border-navy-800 bg-navy-900 p-4">
            <p className="text-sm text-navy-500">{c.category}</p>
            <p className="text-2xl font-bold text-white mt-1">{maskAmount(c.amount, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
          </div>
        ))}
      </div>

      {/* Chart */}
      <div className="mb-5 rounded-xl border border-navy-800 bg-navy-900 p-4">
        <h3 className="mb-4 text-sm font-semibold text-white">Monthly Expenses (Last 6 Months)</h3>
        <ResponsiveContainer width="100%" height={180}>
          <BarChart data={monthlyData} margin={{ top: 0, right: 8, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#1e2a3b" />
            <XAxis dataKey="month" tick={{ fill: "#64748b", fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: "#64748b", fontSize: 11 }} axisLine={false} tickLine={false} width={50}
              tickFormatter={v => `Rs.${(v / 1000).toFixed(0)}k`} />
            <Tooltip content={<CustomTooltip />} cursor={{ fill: "rgba(249,115,22,0.05)" }} />
            <Bar dataKey="amount" radius={[4, 4, 0, 0]}>
              {monthlyData.map((_, i) => <Cell key={i} fill="#f97316" opacity={i === 5 ? 1 : 0.5} />)}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Category tabs + search */}
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex gap-1 rounded-xl bg-navy-900 border border-navy-800 p-1 flex-wrap">
          {["All", ...CATEGORIES].map(c => (
            <button key={c} onClick={() => setCategory(c)}
              className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${category === c ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}>
              {c}
            </button>
          ))}
        </div>
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-navy-500" />
          <input
            className="w-full sm:w-56 rounded-lg bg-navy-800 border border-navy-700 pl-9 pr-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
            placeholder="Search expenses..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
      </div>

      {/* Expense list */}
      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
        {loading ? (
          <div className="py-16 text-center text-sm text-navy-400">{t("loading")}</div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center gap-3 py-16 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-navy-800">
              <Plus className="h-6 w-6 text-navy-600" />
            </div>
            <p className="text-sm text-navy-400">No expenses found</p>
            <button onClick={() => { setEditItem(null); setShowModal(true); }}
              className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600">
              <Plus size={14} /> Add First Expense
            </button>
          </div>
        ) : (
          <>
            <div className="hidden sm:grid grid-cols-12 gap-2 px-4 py-2.5 text-xs font-semibold text-navy-500 border-b border-navy-800">
              <div className="col-span-2">Date</div>
              <div className="col-span-2">Category</div>
              <div className="col-span-4">Description</div>
              <div className="col-span-2">Method</div>
              <div className="col-span-1 text-right">Amount</div>
              <div className="col-span-1 text-right">Actions</div>
            </div>
            {filtered.map(item => (
              <div key={item.id}
                className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/50 hover:bg-navy-800/30 transition text-sm">
                <div className="col-span-4 sm:col-span-2 text-navy-400 text-xs">
                  {formatDate(item.date, dateMode, language)}
                </div>
                <div className="col-span-4 sm:col-span-2">
                  <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-semibold ${CAT_COLORS[item.category_name] || "bg-navy-700 text-navy-400"}`}>
                    {item.category_name || "Other"}
                  </span>
                </div>
                <div className="col-span-12 sm:col-span-4 text-navy-300 text-xs truncate">
                  {item.description || item.notes || "—"}
                </div>
                <div className="col-span-6 sm:col-span-2 text-navy-400 text-xs">
                  {PAYMENT_METHOD_LABELS[item.payment_method] || item.payment_method || "—"}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right font-semibold text-white">
                  {maskAmount(parseFloat(item.amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-2 sm:col-span-1 flex justify-end gap-1">
                  {item.receipt_image_url && (
                    <button onClick={() => setViewReceiptImage(item.receipt_image_url)}
                      className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-orange-400" title="View Receipt">
                      <Image size={13} />
                    </button>
                  )}
                  <button onClick={() => { setEditItem(item); setShowModal(true); }}
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Edit2 size={13} />
                  </button>
                  <button onClick={() => setDeleteItem(item)}
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-red-400">
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>
            ))}
          </>
        )}
      </div>

      {showModal && (
        <ExpenseModal
          editData={editItem}
          categories={categories}
          onClose={() => { setShowModal(false); setEditItem(null); }}
          onSaved={() => { setShowModal(false); setEditItem(null); load(); }}
        />
      )}
      {deleteItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-sm rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl p-6 space-y-4">
            <p className="text-white text-sm">Delete this expense? This cannot be undone.</p>
            {deleteError && <p className="rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">{deleteError}</p>}
            <div className="flex gap-3 justify-end">
              <button disabled={deleting} onClick={() => { setDeleteItem(null); setDeleteError(""); }} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm disabled:opacity-50">Cancel</button>
              <button disabled={deleting} onClick={async () => {
                setDeleting(true);
                setDeleteError("");
                try {
                  await expensesApi.delete(deleteItem.id);
                  load();
                  setDeleteItem(null);
                } catch (e) {
                  setDeleteError(e.response?.data?.error || e.response?.data?.detail || "Couldn't delete this expense. Please try again.");
                }
                setDeleting(false);
              }} className="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600 text-sm disabled:opacity-50">{deleting ? "Deleting…" : "Delete"}</button>
            </div>
          </div>
        </div>
      )}
      {viewReceiptImage && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4" onClick={() => setViewReceiptImage(null)}>
          <img src={viewReceiptImage} alt="Receipt" className="max-h-full max-w-full rounded-xl object-contain" />
          <button className="absolute top-4 right-4 rounded-full bg-white/10 p-2 text-white hover:bg-white/20" onClick={() => setViewReceiptImage(null)}>
            <X className="h-5 w-5" />
          </button>
        </div>
      )}
    </div>
  );
}
