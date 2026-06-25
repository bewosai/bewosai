import { useState, useEffect } from "react";
import { expenses as expensesApi, reports as reportsApi } from "../api";
import { useAuth } from "../context/AuthContext";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import {
  TrendingUp, TrendingDown, Wallet, Plus, X, Calendar,
} from "lucide-react";

const INCOME_CATEGORIES = ["Salary", "Freelance", "Business", "Investment", "Gift", "Other"];
const EXPENSE_CATEGORIES_PERSONAL = ["Food", "Transport", "Health", "Shopping", "Rent", "Utilities", "Entertainment", "Education", "Other"];

function AddTransactionModal({ type, onClose, onSaved }) {
  const [form, setForm] = useState({
    amount: "", category: type === "income" ? "Salary" : "Food",
    date: new Date().toISOString().slice(0, 10), description: "",
  });
  const [saving, setSaving] = useState(false);
  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";
  const cats = type === "income" ? INCOME_CATEGORIES : EXPENSE_CATEGORIES_PERSONAL;

  const submit = async (e) => {
    e.preventDefault();
    if (!form.amount) return;
    setSaving(true);
    try {
      const bid = localStorage.getItem("business_id");
      // For personal, we store income as a negative expense with "INCOME" prefix,
      // or just use expenses with a special category
      await expensesApi.create({
        business: bid,
        amount: form.amount,
        date: form.date,
        description: `[${type === "income" ? "INCOME" : "EXPENSE"}] ${form.category}: ${form.description}`,
        payment_method: "CASH",
      });
      onSaved();
    } catch { } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-sm rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-5 flex items-center justify-between">
          <div className="flex items-center gap-2">
            {type === "income"
              ? <TrendingUp className="h-5 w-5 text-green-400" />
              : <TrendingDown className="h-5 w-5 text-red-400" />}
            <h2 className="font-bold text-white capitalize">Add {type}</h2>
          </div>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        <form onSubmit={submit} className="space-y-3">
          <input type="number" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })}
            placeholder="Amount (Rs.)" className={field} required />
          <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className={field}>
            {cats.map((c) => <option key={c}>{c}</option>)}
          </select>
          <input type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} className={field} />
          <input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })}
            placeholder="Note (optional)" className={field} />
          <div className="flex gap-3 pt-1">
            <button type="submit" disabled={saving}
              className={`flex-1 rounded-xl py-2.5 font-semibold text-white transition disabled:opacity-60 ${type === "income" ? "bg-green-600 hover:bg-green-500" : "bg-red-600 hover:bg-red-500"}`}>
              {saving ? "Saving…" : `Add ${type}`}
            </button>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>Cancel</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function PersonalDashboard() {
  const { user } = useAuth();
  const [data, setData] = useState(null);
  const [recentTx, setRecentTx] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(null); // "income" | "expense"

  const load = () => {
    setLoading(true);
    const bid = localStorage.getItem("business_id");
    Promise.all([
      reportsApi.profit(),
      expensesApi.list({ business: bid, ordering: "-date", page_size: 10 }),
    ])
      .then(([p, e]) => {
        setData(p.data);
        setRecentTx(e.data.results ?? e.data);
      })
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  const income = recentTx.filter((t) => t.description?.includes("[INCOME]"))
    .reduce((s, t) => s + Number(t.amount), 0);
  const exp = recentTx.filter((t) => !t.description?.includes("[INCOME]"))
    .reduce((s, t) => s + Number(t.amount), 0);
  const balance = income - exp;

  return (
    <div>
      <PageHeader
        title={`Hi, ${user?.name || "there"} 👋`}
        subtitle="Your personal finance overview"
      />

      {/* Stats */}
      <div className="grid gap-4 sm:grid-cols-3">
        <div className="rounded-2xl border border-green-500/20 bg-green-500/5 p-5">
          <div className="flex items-center justify-between">
            <p className="text-xs text-navy-400">Income (this period)</p>
            <TrendingUp className="h-4 w-4 text-green-400" />
          </div>
          <p className="mt-2 text-2xl font-extrabold text-white">Rs. {income.toLocaleString()}</p>
        </div>

        <div className="rounded-2xl border border-red-500/20 bg-red-500/5 p-5">
          <div className="flex items-center justify-between">
            <p className="text-xs text-navy-400">Expenses (this period)</p>
            <TrendingDown className="h-4 w-4 text-red-400" />
          </div>
          <p className="mt-2 text-2xl font-extrabold text-white">Rs. {exp.toLocaleString()}</p>
        </div>

        <div className={`rounded-2xl border p-5 ${balance >= 0 ? "border-orange-500/20 bg-orange-500/5" : "border-red-500/20 bg-red-500/5"}`}>
          <div className="flex items-center justify-between">
            <p className="text-xs text-navy-400">Balance</p>
            <Wallet className={`h-4 w-4 ${balance >= 0 ? "text-orange-400" : "text-red-400"}`} />
          </div>
          <p className={`mt-2 text-2xl font-extrabold ${balance >= 0 ? "text-white" : "text-red-400"}`}>
            Rs. {Math.abs(balance).toLocaleString()}
            {balance < 0 && <span className="ml-1 text-sm">deficit</span>}
          </p>
        </div>
      </div>

      {/* Quick add */}
      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        <button
          onClick={() => setModal("income")}
          className="flex items-center gap-3 rounded-2xl border border-green-500/20 bg-green-500/5 p-4 text-left transition hover:border-green-500/40"
        >
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-green-500/15">
            <TrendingUp className="h-5 w-5 text-green-400" />
          </div>
          <div>
            <p className="font-semibold text-white">Add Income</p>
            <p className="text-xs text-navy-400">Salary, freelance, business...</p>
          </div>
          <Plus className="ml-auto h-5 w-5 text-navy-500" />
        </button>

        <button
          onClick={() => setModal("expense")}
          className="flex items-center gap-3 rounded-2xl border border-red-500/20 bg-red-500/5 p-4 text-left transition hover:border-red-500/40"
        >
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-red-500/15">
            <TrendingDown className="h-5 w-5 text-red-400" />
          </div>
          <div>
            <p className="font-semibold text-white">Add Expense</p>
            <p className="text-xs text-navy-400">Food, transport, bills...</p>
          </div>
          <Plus className="ml-auto h-5 w-5 text-navy-500" />
        </button>
      </div>

      {/* Recent transactions */}
      <div className="mt-6">
        <SectionCard title="Recent Transactions">
          {loading ? (
            <p className="py-6 text-center text-sm text-navy-400">Loading…</p>
          ) : recentTx.length ? (
            <div className="space-y-2">
              {recentTx.map((tx) => {
                const isIncome = tx.description?.includes("[INCOME]");
                const cleanDesc = tx.description
                  ?.replace("[INCOME]", "").replace("[EXPENSE]", "").trim() || "Transaction";
                return (
                  <div key={tx.id} className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${isIncome ? "bg-green-500/15" : "bg-red-500/15"}`}>
                        {isIncome ? <TrendingUp className="h-4 w-4 text-green-400" /> : <TrendingDown className="h-4 w-4 text-red-400" />}
                      </div>
                      <div>
                        <p className="text-sm font-medium text-white">{cleanDesc}</p>
                        <p className="text-xs text-navy-400">{tx.date}</p>
                      </div>
                    </div>
                    <p className={`text-sm font-semibold ${isIncome ? "text-green-400" : "text-red-400"}`}>
                      {isIncome ? "+" : "-"}Rs. {Number(tx.amount).toLocaleString()}
                    </p>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <Calendar className="h-12 w-12 text-navy-700" />
              <p className="text-sm text-navy-400">No transactions yet. Add your first one.</p>
            </div>
          )}
        </SectionCard>
      </div>

      {modal && (
        <AddTransactionModal
          type={modal}
          onClose={() => setModal(null)}
          onSaved={() => { setModal(null); load(); }}
        />
      )}
    </div>
  );
}
