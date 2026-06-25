import { useState, useEffect } from "react";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { banking as bankingApi } from "../api";
import { CreditCard, Plus, TrendingUp, TrendingDown, X } from "lucide-react";

function AccountCard({ account, onSelect, selected }) {
  return (
    <button
      onClick={() => onSelect(account)}
      className={`rounded-2xl border p-5 text-left transition w-full ${
        selected ? "border-orange-500 bg-orange-500/5" : "border-navy-800 bg-navy-900 hover:border-navy-700"
      }`}
    >
      <div className="flex items-start justify-between">
        <div>
          <p className="font-semibold text-white">{account.account_name}</p>
          <p className="mt-0.5 text-xs text-navy-400">
            {account.bank_name || "Cash"} · {account.account_type}
          </p>
        </div>
        <CreditCard className={`h-5 w-5 ${selected ? "text-orange-400" : "text-navy-500"}`} />
      </div>
      <p className="mt-3 text-2xl font-bold text-white">
        Rs. {Number(account.balance).toLocaleString()}
      </p>
    </button>
  );
}

function AddAccountModal({ onClose, onSaved }) {
  const [form, setForm] = useState({
    account_name: "", bank_name: "", account_number: "",
    account_type: "CURRENT", opening_balance: "0",
  });
  const [saving, setSaving] = useState(false);
  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const bid = localStorage.getItem("business_id");
      await bankingApi.createAccount({ ...form, business: bid });
      onSaved();
    } catch { } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">Add Bank Account</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        <form onSubmit={submit} className="space-y-3">
          <input name="account_name" value={form.account_name} onChange={(e) => setForm({ ...form, account_name: e.target.value })} placeholder="Account name *" className={field} />
          <input name="bank_name" value={form.bank_name} onChange={(e) => setForm({ ...form, bank_name: e.target.value })} placeholder="Bank name" className={field} />
          <input name="account_number" value={form.account_number} onChange={(e) => setForm({ ...form, account_number: e.target.value })} placeholder="Account number" className={field} />
          <select value={form.account_type} onChange={(e) => setForm({ ...form, account_type: e.target.value })} className={field}>
            <option value="CURRENT">Current</option>
            <option value="SAVINGS">Savings</option>
            <option value="CASH">Cash</option>
          </select>
          <input type="number" value={form.opening_balance} onChange={(e) => setForm({ ...form, opening_balance: e.target.value })} placeholder="Opening balance" className={field} />
          <div className="flex gap-3 pt-1">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>{saving ? "Saving…" : "Add Account"}</PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>Cancel</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function BankingPage() {
  const [accounts, setAccounts] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [selected, setSelected] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showAdd, setShowAdd] = useState(false);

  const load = () => {
    setLoading(true);
    bankingApi.accounts()
      .then((r) => {
        const accs = r.data.results ?? r.data;
        setAccounts(accs);
        if (accs.length > 0) setSelected(accs[0]);
      })
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  useEffect(() => {
    if (!selected) return;
    bankingApi.transactions({ account: selected.id })
      .then((r) => setTransactions(r.data.results ?? r.data));
  }, [selected]);

  const totalBalance = accounts.reduce((s, a) => s + Number(a.balance), 0);

  return (
    <div>
      <PageHeader
        title="Banking & Cash"
        subtitle="Track all bank accounts and transactions."
        action={
          <PrimaryButton onClick={() => setShowAdd(true)}>
            <Plus className="h-4 w-4" /> Add Account
          </PrimaryButton>
        }
      />

      {/* Total balance */}
      <div className="mb-6 rounded-2xl border border-orange-500/30 bg-orange-500/5 p-5">
        <p className="text-xs text-navy-400">Total Balance (All Accounts)</p>
        <p className="mt-1 text-3xl font-extrabold text-white">
          Rs. {totalBalance.toLocaleString()}
        </p>
      </div>

      {/* Accounts */}
      {loading ? (
        <p className="text-sm text-navy-400">Loading…</p>
      ) : accounts.length ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {accounts.map((acc) => (
            <AccountCard key={acc.id} account={acc} selected={selected?.id === acc.id} onSelect={setSelected} />
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center gap-3 py-12 text-center">
          <CreditCard className="h-12 w-12 text-navy-700" />
          <p className="text-sm text-navy-400">No bank accounts yet.</p>
          <PrimaryButton onClick={() => setShowAdd(true)}><Plus className="h-4 w-4" /> Add Account</PrimaryButton>
        </div>
      )}

      {/* Transactions */}
      {selected && (
        <div className="mt-6">
          <SectionCard title={`Transactions — ${selected.account_name}`}>
            {transactions.length ? (
              <div className="space-y-2">
                {transactions.map((tx) => (
                  <div key={tx.id} className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${tx.transaction_type === "CREDIT" ? "bg-green-500/15" : "bg-red-500/15"}`}>
                        {tx.transaction_type === "CREDIT"
                          ? <TrendingUp className="h-4 w-4 text-green-400" />
                          : <TrendingDown className="h-4 w-4 text-red-400" />}
                      </div>
                      <div>
                        <p className="text-sm font-medium text-white">{tx.description || tx.reference || "Transaction"}</p>
                        <p className="text-xs text-navy-400">{tx.date}</p>
                      </div>
                    </div>
                    <p className={`text-sm font-semibold ${tx.transaction_type === "CREDIT" ? "text-green-400" : "text-red-400"}`}>
                      {tx.transaction_type === "CREDIT" ? "+" : "-"}Rs. {Number(tx.amount).toLocaleString()}
                    </p>
                  </div>
                ))}
              </div>
            ) : (
              <p className="py-6 text-center text-sm text-navy-400">No transactions for this account.</p>
            )}
          </SectionCard>
        </div>
      )}

      {showAdd && (
        <AddAccountModal onClose={() => setShowAdd(false)} onSaved={() => { setShowAdd(false); load(); }} />
      )}
    </div>
  );
}
