import { useEffect, useState } from "react";
import { X, Loader, HandCoins } from "lucide-react";
import { sales as salesApi, banking as bankingApi } from "../../api";
import { todayStr } from "../../utils/dates";

const METHODS = [
  ["CASH", "Cash"], ["BANK", "Bank"], ["ESEWA", "eSewa"], ["KHALTI", "Khalti"],
];

// Receive (part of) what's still due on one invoice. Saved as a payment from
// the invoice's customer that settles this invoice (not their oldest one), so
// it shows in their ledger, the day book and cash/bank like any payment.
export default function ReceivePaymentModal({ sale, onClose, onReceived }) {
  const due = parseFloat(sale.due_amount || 0);
  const [amount, setAmount] = useState(due.toFixed(2));
  const [method, setMethod] = useState("CASH");
  const [bankAccount, setBankAccount] = useState("");
  const [date, setDate] = useState(todayStr());
  const [note, setNote] = useState("");
  const [accounts, setAccounts] = useState([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    bankingApi.accounts({ page_size: 1000 }).then(r => setAccounts(r.data.results ?? r.data)).catch(() => {});
  }, []);

  const value = parseFloat(amount) || 0;
  const tooMuch = value > due + 0.005;
  const needsAccount = method !== "CASH" && accounts.length > 0;

  const submit = async (e) => {
    e.preventDefault();
    if (value <= 0 || tooMuch) return;
    setSaving(true);
    setError("");
    try {
      const { data } = await salesApi.receivePayment(sale.id, {
        amount: value.toFixed(2), payment_method: method, date, note,
        bank_account: method !== "CASH" && bankAccount ? bankAccount : null,
      });
      onReceived(data.message);
    } catch (err) {
      const d = err.response?.data;
      setError(d?.message || (d && typeof d === "object" ? Object.values(d).flat().join(" ") : "") || "Couldn't record the payment.");
    } finally { setSaving(false); }
  };

  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white focus:border-orange-500 focus:outline-none";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" onClick={onClose}>
      <form onSubmit={submit} onClick={e => e.stopPropagation()}
        className="w-full max-w-md space-y-3 rounded-2xl border border-navy-700 bg-navy-900 p-5 shadow-2xl">
        <div className="flex items-start justify-between">
          <div>
            <h2 className="flex items-center gap-2 font-bold text-white"><HandCoins className="h-5 w-5 text-green-400" /> Receive Payment</h2>
            <p className="mt-0.5 text-xs text-navy-400">
              Invoice {sale.invoice_number} · {sale.customer_name || sale.party_name} · Due <b className="text-white">Rs {due.toFixed(2)}</b>
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close"><X className="h-5 w-5 text-navy-400" /></button>
        </div>

        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Amount received (Rs)</label>
          <input type="number" min="0" step="0.01" autoFocus value={amount} onChange={e => setAmount(e.target.value)}
            className={`${field} ${tooMuch ? "border-red-500" : ""}`} />
          {tooMuch && <p className="mt-1 text-xs text-red-400">Only Rs {due.toFixed(2)} is due on this invoice.</p>}
          {!tooMuch && value > 0 && value < due && (
            <p className="mt-1 text-xs text-navy-400">Rs {(due - value).toFixed(2)} will still be due.</p>
          )}
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Method</label>
            <select value={method} onChange={e => setMethod(e.target.value)} className={field}>
              {METHODS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </select>
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Date</label>
            <input type="date" value={date} onChange={e => setDate(e.target.value)} className={field} />
          </div>
        </div>

        {needsAccount && (
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Into account</label>
            <select value={bankAccount} onChange={e => setBankAccount(e.target.value)} className={field}>
              <option value="">Not linked to an account</option>
              {accounts.map(a => <option key={a.id} value={a.id}>{a.bank_name || a.account_name}</option>)}
            </select>
          </div>
        )}

        <input value={note} onChange={e => setNote(e.target.value)} placeholder="Note (optional)" className={field} />

        {error && <p className="rounded-xl bg-red-500/10 px-3 py-2 text-sm text-red-400">{error}</p>}

        <button type="submit" disabled={saving || value <= 0 || tooMuch}
          className="flex w-full items-center justify-center gap-2 rounded-xl bg-green-600 py-3 font-bold text-white hover:bg-green-500 disabled:opacity-50">
          {saving && <Loader className="h-4 w-4 animate-spin" />} Receive Rs {value.toFixed(2)}
        </button>
      </form>
    </div>
  );
}
