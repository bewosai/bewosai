import { useState, useEffect, useRef } from "react";
import { banking as bankingApi } from "../api";
import { useTranslation } from "../utils/translations";
import { useDateFormat } from "../context/AppSettingsContext";
import {
  CreditCard, Plus, TrendingUp, TrendingDown, X, QrCode,
  Trash2, Edit2, Upload, AlertTriangle, Loader, RefreshCw, Search,
} from "lucide-react";

const today = () => new Date().toISOString().slice(0, 10);

/* ── Confirm Dialog ─────────────────────────────────────────────────────── */
function ConfirmDialog({ title, body, error, busy, onConfirm, onCancel }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-2xl border border-navy-800 bg-navy-900 p-6 space-y-4">
        <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-red-500/10">
          <AlertTriangle className="h-6 w-6 text-red-400" />
        </div>
        <h3 className="text-center text-sm font-bold text-white">{title}</h3>
        {body && <p className="text-center text-xs text-navy-400">{body}</p>}
        {error && (
          <p className="flex items-center gap-1.5 rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">
            <AlertTriangle className="h-3.5 w-3.5 shrink-0" /> {error}
          </p>
        )}
        <div className="flex gap-3">
          <button onClick={onCancel} disabled={busy} className="flex-1 rounded-xl border border-navy-700 py-2.5 text-sm font-medium text-navy-400 hover:bg-navy-800 disabled:opacity-50">Cancel</button>
          <button onClick={onConfirm} disabled={busy} className="flex-1 rounded-xl py-2.5 text-sm font-semibold text-white bg-red-500 hover:bg-red-600 disabled:opacity-50">
            {busy ? "Deleting…" : "Delete"}
          </button>
        </div>
      </div>
    </div>
  );
}

// Mirrors backend/banking/models.py BankAccount.TYPE_LIMITS — types not
// listed here are unlimited (Cash, IME Pay, Mobile Banking, Other).
const ACCOUNT_TYPE_LIMITS = { BANK: 2, ESEWA: 1, KHALTI: 1, CONNECT_IPS: 1 };

/* ── Add/Edit Account Modal ─────────────────────────────────────────────── */
function AccountModal({ editData, accounts = [], onClose, onSaved }) {
  const [form, setForm] = useState({
    account_name: editData?.account_name || "",
    bank_name: editData?.bank_name || "",
    account_number: editData?.account_number || "",
    account_type: editData?.account_type || "CASH",
    opening_balance: editData?.opening_balance || "0",
  });

  // Only counts against active accounts other than the one being edited —
  // matches the backend's own validate_account_type exactly, so the option
  // being disabled here always agrees with what the server would reject.
  const countOfType = (type) => accounts.filter(a =>
    a.account_type === type && a.is_active !== false && a.id !== editData?.id
  ).length;
  const isTypeFull = (type) => {
    const limit = ACCOUNT_TYPE_LIMITS[type];
    return limit != null && countOfType(type) >= limit;
  };
  const [qrFile, setQrFile] = useState(null);
  const [qrPreview, setQrPreview] = useState(editData?.qr_code_url || null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const fileRef = useRef();

  const handleFile = (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setQrFile(f);
    setQrPreview(URL.createObjectURL(f));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.account_name.trim()) { setError("Account name is required."); return; }
    setSaving(true);
    try {
      const fd = new FormData();
      Object.entries(form).forEach(([k, v]) => fd.append(k, v));
      if (qrFile) fd.append("qr_code", qrFile);
      if (editData?.id) {
        await bankingApi.updateAccount(editData.id, fd);
      } else {
        await bankingApi.createAccount(fd);
      }
      onSaved();
    } catch (e) {
      const data = e.response?.data;
      setError(data?.detail || data?.account_type?.[0] || data?.error || "Failed to save account.");
    } finally {
      setSaving(false);
    }
  };

  const field = "w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{editData?.id ? "Edit Account" : "Add Bank Account"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {error && <p className="mb-3 rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">{error}</p>}
        <form onSubmit={handleSubmit} className="space-y-3">
          <input className={field} placeholder="Account name *" value={form.account_name} onChange={e => setForm(f => ({ ...f, account_name: e.target.value }))} />
          <input className={field} placeholder="Bank name (e.g., NIC Asia)" value={form.bank_name} onChange={e => setForm(f => ({ ...f, bank_name: e.target.value }))} />
          <input className={field} placeholder="Account number" value={form.account_number} onChange={e => setForm(f => ({ ...f, account_number: e.target.value }))} />
          <select className={field} value={form.account_type} onChange={e => setForm(f => ({ ...f, account_type: e.target.value }))}>
            <option value="CASH">Cash (Petty Cash)</option>
            <option value="BANK" disabled={isTypeFull("BANK")}>Bank{isTypeFull("BANK") ? ` (limit ${ACCOUNT_TYPE_LIMITS.BANK} reached)` : ""}</option>
            <option value="ESEWA" disabled={isTypeFull("ESEWA")}>eSewa{isTypeFull("ESEWA") ? " (limit reached)" : ""}</option>
            <option value="KHALTI" disabled={isTypeFull("KHALTI")}>Khalti{isTypeFull("KHALTI") ? " (limit reached)" : ""}</option>
            <option value="CONNECT_IPS" disabled={isTypeFull("CONNECT_IPS")}>Connect IPS{isTypeFull("CONNECT_IPS") ? " (limit reached)" : ""}</option>
            <option value="IME_PAY">IME Pay</option>
            <option value="MOBILE_BANKING">Mobile Banking</option>
            <option value="OTHER">Other</option>
          </select>
          {isTypeFull(form.account_type) && (
            <p className="text-xs text-amber-400">
              You've reached the limit for this account type — remove or deactivate one first, or pick another type.
            </p>
          )}
          <input type="number" className={field} placeholder="Opening balance (Rs.)" value={form.opening_balance} onChange={e => setForm(f => ({ ...f, opening_balance: e.target.value }))} />

          {/* QR Code Upload */}
          <div>
            <p className="mb-1.5 text-xs font-semibold text-navy-400">Payment QR Code (eSewa / Khalti / Bank)</p>
            <div
              className="relative flex flex-col items-center justify-center rounded-xl border-2 border-dashed border-navy-700 p-4 text-center cursor-pointer hover:border-orange-500/50 transition"
              onClick={() => fileRef.current?.click()}
            >
              {qrPreview ? (
                <div className="relative">
                  <img src={qrPreview} alt="QR" className="h-32 w-32 rounded-lg object-contain" />
                  <button type="button" onClick={e => { e.stopPropagation(); setQrFile(null); setQrPreview(null); }}
                    className="absolute -right-2 -top-2 rounded-full bg-red-500 p-0.5 text-white">
                    <X className="h-3 w-3" />
                  </button>
                </div>
              ) : (
                <>
                  <QrCode className="h-8 w-8 text-navy-600 mb-2" />
                  <p className="text-xs text-navy-400">Click to upload QR code image</p>
                  <p className="text-[10px] text-navy-600 mt-0.5">PNG, JPG up to 5MB</p>
                </>
              )}
              <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={handleFile} />
            </div>
          </div>

          <div className="flex gap-3 pt-1">
            <button type="submit" disabled={saving || isTypeFull(form.account_type)} className="flex-1 rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50">
              {saving ? "Saving..." : editData?.id ? "Save Changes" : "Add Account"}
            </button>
            <button type="button" onClick={onClose} className="rounded-xl border border-navy-700 px-4 py-2.5 text-sm text-navy-400 hover:bg-navy-800">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ── Add Transaction Modal ──────────────────────────────────────────────── */
function TransactionModal({ account, onClose, onSaved }) {
  const [form, setForm] = useState({ transaction_type: "CREDIT", amount: "", date: today(), description: "", reference: "" });
  const [saving, setSaving] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.amount || parseFloat(form.amount) <= 0) return;
    setSaving(true);
    try {
      await bankingApi.addTransaction({ ...form, account: account.id });
      onSaved();
    } catch {}
    setSaving(false);
  };

  const field = "w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="font-bold text-white">Add Transaction — {account.account_name}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        <form onSubmit={handleSubmit} className="space-y-3">
          <div className="grid grid-cols-2 gap-2">
            {["CREDIT", "DEBIT"].map(type => (
              <button key={type} type="button" onClick={() => setForm(f => ({ ...f, transaction_type: type }))}
                className={`rounded-lg py-2.5 text-sm font-semibold transition ${
                  form.transaction_type === type
                    ? type === "CREDIT" ? "bg-green-500 text-white" : "bg-red-500 text-white"
                    : "border border-navy-700 text-navy-400 hover:bg-navy-800"
                }`}>
                {type === "CREDIT" ? "Money In (+)" : "Money Out (-)"}
              </button>
            ))}
          </div>
          <input type="number" min="0.01" step="0.01" className={field} placeholder="Amount (Rs.) *" value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} required />
          <input type="date" className={field} value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} />
          <input className={field} placeholder="Description" value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
          <input className={field} placeholder="Reference / Cheque no." value={form.reference} onChange={e => setForm(f => ({ ...f, reference: e.target.value }))} />
          <div className="flex gap-3 pt-1">
            <button type="submit" disabled={saving} className="flex-1 rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50">
              {saving ? "Saving..." : "Add Transaction"}
            </button>
            <button type="button" onClick={onClose} className="rounded-xl border border-navy-700 px-4 py-2.5 text-sm text-navy-400 hover:bg-navy-800">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ── QR Code Display Modal ──────────────────────────────────────────────── */
function QrModal({ account, onClose }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-xs rounded-2xl border border-navy-700 bg-navy-900 p-6 text-center">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="font-bold text-white">Payment QR</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        <p className="text-sm text-navy-300 mb-3">{account.account_name}</p>
        {account.qr_code_url ? (
          <img src={account.qr_code_url} alt="QR Code" className="mx-auto max-h-64 rounded-xl object-contain" />
        ) : (
          <p className="text-xs text-navy-500">No QR code uploaded.</p>
        )}
        {account.account_number && (
          <p className="mt-3 text-xs text-navy-400">Acc: {account.account_number}</p>
        )}
        <button onClick={onClose} className="mt-4 w-full rounded-xl border border-navy-700 py-2.5 text-sm text-navy-400 hover:bg-navy-800">Close</button>
      </div>
    </div>
  );
}

/* ── Main BankingPage ───────────────────────────────────────────────────── */
export default function BankingPage() {
  const { t } = useTranslation();
  const formatDate = useDateFormat();
  const [accounts, setAccounts] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [selected, setSelected] = useState(null);
  const [loading, setLoading] = useState(true);
  const [txLoading, setTxLoading] = useState(false);
  const [showAccountModal, setShowAccountModal] = useState(false);
  const [editAccount, setEditAccount] = useState(null);
  const [showTxModal, setShowTxModal] = useState(false);
  const [showQr, setShowQr] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [confirmTx, setConfirmTx] = useState(null);
  const [deleteError, setDeleteError] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [txSearch, setTxSearch] = useState("");

  const loadAccounts = () => {
    setLoading(true);
    bankingApi.accounts()
      .then(r => {
        const accs = r.data.results ?? r.data;
        setAccounts(accs);
        if (!selected && accs.length > 0) setSelected(accs[0]);
        else if (selected) {
          const updated = accs.find(a => a.id === selected.id);
          if (updated) setSelected(updated);
        }
      })
      .finally(() => setLoading(false));
  };

  const loadTransactions = (accountId) => {
    setTxLoading(true);
    bankingApi.transactions({ account: accountId })
      .then(r => setTransactions(r.data.results ?? r.data))
      .catch(() => setTransactions([]))
      .finally(() => setTxLoading(false));
  };

  useEffect(loadAccounts, []);
  useEffect(() => {
    if (selected) loadTransactions(selected.id);
  }, [selected]);

  const handleDeleteAccount = async () => {
    setDeleteError("");
    setDeleting(true);
    try {
      await bankingApi.deleteAccount(confirm.id);
      if (selected?.id === confirm.id) setSelected(null);
      setConfirm(null);
      loadAccounts();
    } catch (err) {
      setDeleteError(err.response?.data?.error || err.response?.data?.detail || "Could not delete this account.");
    } finally {
      setDeleting(false);
    }
  };

  const handleDeleteTx = async () => {
    setDeleteError("");
    setDeleting(true);
    try {
      await bankingApi.deleteTransaction(confirmTx.id);
      setConfirmTx(null);
      if (selected) loadTransactions(selected.id);
      loadAccounts();
    } catch (err) {
      setDeleteError(err.response?.data?.error || err.response?.data?.detail || "Could not delete this transaction.");
    } finally {
      setDeleting(false);
    }
  };

  const filteredTransactions = transactions.filter((t) => {
    if (!txSearch.trim()) return true;
    const q = txSearch.toLowerCase();
    return (t.description || "").toLowerCase().includes(q) || (t.reference || "").toLowerCase().includes(q);
  });

  const totalBalance = accounts.reduce((s, a) => s + Number(a.balance || 0), 0);
  const totalCredit = transactions.filter(t => t.transaction_type === "CREDIT").reduce((s, t) => s + Number(t.amount), 0);
  const totalDebit = transactions.filter(t => t.transaction_type === "DEBIT").reduce((s, t) => s + Number(t.amount), 0);

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">{t("banking")}</h1>
          <p className="text-sm text-navy-500">Manage accounts, transactions and QR payments</p>
        </div>
        <button onClick={() => { setEditAccount(null); setShowAccountModal(true); }}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600">
          <Plus className="h-4 w-4" /> Add Account
        </button>
      </div>

      {/* Total balance */}
      <div className="rounded-2xl border border-orange-500/20 bg-orange-500/5 p-5">
        <p className="text-xs text-navy-400">Total Balance (All Accounts)</p>
        <p className="mt-1 text-3xl font-extrabold text-white">Rs. {totalBalance.toLocaleString()}</p>
        <p className="mt-0.5 text-xs text-navy-500">{accounts.length} account{accounts.length !== 1 ? "s" : ""}</p>
      </div>

      {loading ? (
        <div className="flex justify-center py-16"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : accounts.length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-16 rounded-2xl border border-navy-800 bg-navy-900 text-center">
          <CreditCard className="h-12 w-12 text-navy-700" />
          <p className="text-sm text-navy-400">No bank accounts yet</p>
          <button onClick={() => setShowAccountModal(true)} className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600">
            <Plus className="h-4 w-4" /> Add First Account
          </button>
        </div>
      ) : (
        <>
          {/* Account cards */}
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {accounts.map(acc => (
              <div key={acc.id}
                className={`relative rounded-2xl border p-4 cursor-pointer transition ${selected?.id === acc.id ? "border-orange-500 bg-orange-500/5" : "border-navy-800 bg-navy-900 hover:border-navy-700"}`}
                onClick={() => setSelected(acc)}>
                <div className="flex items-start justify-between">
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold text-white truncate">{acc.account_name}</p>
                    <p className="text-xs text-navy-400 mt-0.5">{acc.bank_name || "Cash"} · {acc.account_type}</p>
                    {acc.account_number && <p className="text-xs text-navy-500 mt-0.5">{acc.account_number}</p>}
                  </div>
                  <CreditCard className={`h-5 w-5 shrink-0 ml-2 ${selected?.id === acc.id ? "text-orange-400" : "text-navy-500"}`} />
                </div>
                <p className="mt-3 text-2xl font-bold text-white">Rs. {Number(acc.balance || 0).toLocaleString()}</p>
                <div className="mt-3 flex gap-1">
                  {acc.qr_code_url && (
                    <button onClick={e => { e.stopPropagation(); setShowQr(acc); }}
                      className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-orange-500/40 hover:text-orange-400" title="Show QR">
                      <QrCode className="h-3.5 w-3.5" />
                    </button>
                  )}
                  <button onClick={e => { e.stopPropagation(); setEditAccount(acc); setShowAccountModal(true); }}
                    className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-orange-500/40 hover:text-orange-400" title="Edit">
                    <Edit2 className="h-3.5 w-3.5" />
                  </button>
                  <button onClick={e => { e.stopPropagation(); setConfirm(acc); }}
                    className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-red-500/40 hover:text-red-400" title="Delete">
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Selected account transactions */}
          {selected && (
            <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
              <div className="flex items-center justify-between border-b border-navy-800 px-5 py-3.5">
                <div>
                  <h2 className="font-semibold text-white">{selected.account_name} — Transactions</h2>
                  <div className="mt-0.5 flex gap-3 text-xs">
                    <span className="text-green-400">In: Rs. {totalCredit.toLocaleString()}</span>
                    <span className="text-red-400">Out: Rs. {totalDebit.toLocaleString()}</span>
                  </div>
                </div>
                <button onClick={() => setShowTxModal(true)}
                  className="flex items-center gap-1.5 rounded-xl bg-orange-500 px-3 py-2 text-xs font-semibold text-white hover:bg-orange-600">
                  <Plus className="h-3.5 w-3.5" /> Add
                </button>
              </div>
              {transactions.length > 0 && (
                <div className="border-b border-navy-800 px-5 py-3">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
                    <input
                      value={txSearch}
                      onChange={(e) => setTxSearch(e.target.value)}
                      placeholder="Search description, reference…"
                      className="w-full rounded-lg border border-navy-700 bg-navy-800 py-2 pl-9 pr-3 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                    />
                  </div>
                </div>
              )}
              {txLoading ? (
                <div className="flex justify-center py-10"><Loader className="h-5 w-5 animate-spin text-orange-500" /></div>
              ) : transactions.length === 0 ? (
                <p className="py-10 text-center text-sm text-navy-400">No transactions yet</p>
              ) : filteredTransactions.length === 0 ? (
                <p className="py-10 text-center text-sm text-navy-400">No matching transactions</p>
              ) : (
                <div className="divide-y divide-navy-800/50">
                  {filteredTransactions.map(tx => (
                    <div key={tx.id} className="flex items-center gap-3 px-5 py-3 hover:bg-navy-800/30 transition">
                      <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-lg ${tx.transaction_type === "CREDIT" ? "bg-green-500/10" : "bg-red-500/10"}`}>
                        {tx.transaction_type === "CREDIT"
                          ? <TrendingUp className="h-4 w-4 text-green-400" />
                          : <TrendingDown className="h-4 w-4 text-red-400" />}
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm text-white truncate">{tx.description || tx.reference || tx.transaction_type}</p>
                        <p className="text-xs text-navy-500">{formatDate(tx.date)}</p>
                      </div>
                      <p className={`shrink-0 text-sm font-semibold ${tx.transaction_type === "CREDIT" ? "text-green-400" : "text-red-400"}`}>
                        {tx.transaction_type === "CREDIT" ? "+" : "-"}Rs. {Number(tx.amount).toLocaleString()}
                      </p>
                      <button onClick={() => { setDeleteError(""); setConfirmTx(tx); }}
                        className="shrink-0 rounded-lg p-1.5 text-navy-600 hover:text-red-400 hover:bg-red-500/10">
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </>
      )}

      {/* Modals */}
      {showAccountModal && (
        <AccountModal
          editData={editAccount}
          accounts={accounts}
          onClose={() => { setShowAccountModal(false); setEditAccount(null); }}
          onSaved={() => { setShowAccountModal(false); setEditAccount(null); loadAccounts(); }}
        />
      )}
      {showTxModal && selected && (
        <TransactionModal
          account={selected}
          onClose={() => setShowTxModal(false)}
          onSaved={() => { setShowTxModal(false); loadTransactions(selected.id); loadAccounts(); }}
        />
      )}
      {showQr && <QrModal account={showQr} onClose={() => setShowQr(null)} />}
      {confirm && (
        <ConfirmDialog
          title={`Delete "${confirm.account_name}"?`}
          body="All transactions for this account will also be deleted."
          error={deleteError}
          busy={deleting}
          onConfirm={handleDeleteAccount}
          onCancel={() => { setConfirm(null); setDeleteError(""); }}
        />
      )}
      {confirmTx && (
        <ConfirmDialog
          title={`Delete this ${confirmTx.transaction_type === "CREDIT" ? "credit" : "debit"} of Rs. ${Number(confirmTx.amount).toLocaleString()}?`}
          body="This will adjust the account balance immediately. It cannot be undone."
          error={deleteError}
          busy={deleting}
          onConfirm={handleDeleteTx}
          onCancel={() => { setConfirmTx(null); setDeleteError(""); }}
        />
      )}
    </div>
  );
}
