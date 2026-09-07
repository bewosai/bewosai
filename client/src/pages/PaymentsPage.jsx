import { useState, useEffect, useMemo } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Plus, ArrowDownLeft, ArrowUpRight, Wallet, Clock,
  AlertTriangle, Check, Printer, X, AlertCircle, ChevronDown,
} from "lucide-react";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import { parties as partiesApi, banking as bankingApi } from "../api/index.js";
import { adToBS, formatBS } from "../utils/nepaliDate";
import { PAYMENT_METHODS, CURRENCY } from "../constants";
import Modal from "../components/common/Modal";
import ConfirmDialog from "../components/common/ConfirmDialog";
import EmptyState from "../components/common/EmptyState";
import TabBar from "../components/common/TabBar";
import SearchBar from "../components/common/SearchBar";
import StatusBadge from "../components/common/StatusBadge";
import LoadingSpinner from "../components/common/LoadingSpinner";
import DatePicker from "../components/common/DatePicker";

const today = () => new Date().toISOString().slice(0, 10);
const F = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500 transition";
// PartyPayment.payment_method only accepts these values on the backend (see backend/parties/models.py METHOD_CHOICES) —
// other PAYMENT_METHODS entries (IME_PAY, MOBILE, CHEQUE, CREDIT) would 400 if submitted here.
const PARTY_PAYMENT_METHOD_VALUES = ["CASH", "BANK", "ESEWA", "KHALTI"];

/* ─── Payment Form Modal ─── */
function PaymentModal({ type, onClose, onSaved }) {
  const { language } = useAppSettings();
  const bid = localStorage.getItem("business_id");

  const [form, setForm] = useState({
    party: "",
    amount: "",
    payment_method: "CASH",
    bank_account: "",
    date: today(),
    note: "",
    payment_type: type, // "IN" or "OUT"
  });
  const [parties, setParties] = useState([]);
  const [bankAccounts, setBankAccounts] = useState([]);
  const [partySearch, setPartySearch] = useState("");
  const [showDrop, setShowDrop] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const partyType = type === "IN" ? "CUSTOMER" : "SUPPLIER";
    // page_size: every party must be searchable here, not just the first
    // page — this list is a search-to-select picker, not a paged table.
    partiesApi.list({ business: bid, party_type: partyType, page_size: 1000 })
      .then(r => setParties(r.data.results ?? r.data))
      .catch(() => {});
    // Also load "BOTH" type
    partiesApi.list({ business: bid, party_type: "BOTH", page_size: 1000 })
      .then(r => setParties(prev => {
        const ids = new Set(prev.map(p => p.id));
        return [...prev, ...(r.data.results ?? r.data).filter(p => !ids.has(p.id))];
      }))
      .catch(() => {});
    bankingApi.accounts({ business: bid, page_size: 1000 })
      .then(r => setBankAccounts(r.data.results ?? r.data))
      .catch(() => {});
  }, [type]);

  const filteredParties = parties.filter(p =>
    p.name.toLowerCase().includes(partySearch.toLowerCase())
  );

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (!form.party) { setError("Please select a party."); return; }
    if (!form.amount || parseFloat(form.amount) <= 0) { setError("Enter a valid amount."); return; }
    if (form.payment_method !== "CASH" && !form.bank_account) {
      setError("Select which account this payment should hit.");
      return;
    }
    setSaving(true);
    try {
      await partiesApi.addPayment({
        party: form.party,
        payment_type: form.payment_type,
        amount: parseFloat(form.amount),
        payment_method: form.payment_method,
        bank_account: form.payment_method === "CASH" ? null : form.bank_account,
        date: form.date,
        note: form.note,
      });
      onSaved();
    } catch (e) {
      setError(e.response?.data?.detail || e.response?.data?.bank_account?.[0] || "Failed to save payment.");
    } finally {
      setSaving(false);
    }
  };

  const isIn = type === "IN";
  const title = isIn ? "Record Payment Received" : "Record Payment Made";
  const partyLabel = isIn ? "Customer *" : "Supplier *";

  return (
    <Modal
      title={title}
      onClose={onClose}
      size="sm"
      footer={
        <div className="flex justify-end gap-3">
          <button onClick={onClose} className="rounded-xl border border-navy-700 px-4 py-2 text-sm text-navy-400 hover:bg-navy-800">
            Cancel
          </button>
          <button
            disabled={saving}
            onClick={handleSubmit}
            className={`rounded-xl px-5 py-2 text-sm font-semibold text-white transition disabled:opacity-50 ${
              isIn ? "bg-green-600 hover:bg-green-700" : "bg-red-500 hover:bg-red-600"
            }`}
          >
            {saving ? "Saving…" : isIn ? "Record Receipt" : "Record Payment"}
          </button>
        </div>
      }
    >
      <div className="space-y-3">
        {error && (
          <div className="flex items-center gap-2 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">
            <AlertCircle className="h-4 w-4 shrink-0" /> {error}
          </div>
        )}

        {/* Party selector */}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">{partyLabel}</label>
          <div className="relative">
            <input
              className={F}
              placeholder={`Search ${isIn ? "customer" : "supplier"}…`}
              value={partySearch}
              onChange={e => { setPartySearch(e.target.value); setShowDrop(true); }}
              onFocus={() => setShowDrop(true)}
            />
            {showDrop && filteredParties.length > 0 && (
              <div className="absolute z-10 mt-1 w-full rounded-xl border border-navy-700 bg-navy-900 shadow-xl max-h-48 overflow-y-auto">
                {filteredParties.slice(0, 20).map(p => (
                  <button
                    key={p.id}
                    type="button"
                    className="w-full px-3 py-2.5 text-left text-sm text-white hover:bg-navy-800 flex items-center justify-between"
                    onMouseDown={() => {
                      setForm(f => ({ ...f, party: p.id }));
                      setPartySearch(p.name);
                      setShowDrop(false);
                    }}
                  >
                    <span>{p.name}</span>
                    {p.phone && <span className="text-xs text-navy-500">{p.phone}</span>}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Amount */}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Amount ({CURRENCY}) *</label>
          <input
            type="number" min="0.01" step="0.01"
            className={F}
            placeholder="0.00"
            value={form.amount}
            onChange={e => setForm(f => ({ ...f, amount: e.target.value }))}
          />
        </div>

        {/* Payment Method */}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Payment Method</label>
          <select className={F} value={form.payment_method}
            onChange={e => setForm(f => ({ ...f, payment_method: e.target.value }))}>
            {PAYMENT_METHODS.filter(m => PARTY_PAYMENT_METHOD_VALUES.includes(m.value)).map(m => (
              <option key={m.value} value={m.value}>{m.label}</option>
            ))}
          </select>
        </div>

        {/* Bank Account — only for non-cash methods, so the payment
            actually shows up on that account's Bank Statement instead of
            payment_method being purely cosmetic. */}
        {form.payment_method !== "CASH" && (
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Account *</label>
            {bankAccounts.length === 0 ? (
              <p className="rounded-xl border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-300">
                No bank accounts yet — add one in Banking, or switch this to Cash.
              </p>
            ) : (
              <select className={F} value={form.bank_account}
                onChange={e => setForm(f => ({ ...f, bank_account: e.target.value }))}>
                <option value="">Select account…</option>
                {bankAccounts.map(a => (
                  <option key={a.id} value={a.id}>{a.account_name}{a.bank_name ? ` (${a.bank_name})` : ""}</option>
                ))}
              </select>
            )}
          </div>
        )}

        {/* Date */}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Date *</label>
          <DatePicker value={form.date} onChange={(d) => setForm(f => ({ ...f, date: d }))} />
        </div>

        {/* Note */}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Note</label>
          <textarea
            rows={2} className={`${F} resize-none`}
            placeholder="Reference, cheque no., remarks…"
            value={form.note}
            onChange={e => setForm(f => ({ ...f, note: e.target.value }))}
          />
        </div>
      </div>
    </Modal>
  );
}

/* ─── Payment Row ─── */
function PaymentRow({ pay, onDelete }) {
  const { dateMode, language } = useAppSettings();
  const maskAmount = usePrivateAmount();
  const isIn = pay.payment_type === "IN";

  const dateStr = pay.date;
  const dateDisplay = (() => {
    if (!dateStr) return "";
    const d = new Date(dateStr);
    if (dateMode === "BS") return formatBS(adToBS(d), language);
    return d.toLocaleDateString("en-GB");
  })();

  const methodLabel = PAYMENT_METHODS.find(m => m.value === pay.payment_method)?.label || pay.payment_method;

  return (
    <div className="flex items-center gap-3 border-t border-navy-800/50 px-4 py-3 hover:bg-navy-800/20 transition">
      <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-lg ${isIn ? "bg-green-500/10" : "bg-red-500/10"}`}>
        {isIn
          ? <ArrowDownLeft className="h-4 w-4 text-green-400" />
          : <ArrowUpRight className="h-4 w-4 text-red-400" />
        }
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold text-white truncate">
          {pay.party_name || "—"}
        </p>
        <p className="text-xs text-navy-500">
          {dateDisplay} · {methodLabel}
          {pay.note && ` · ${pay.note}`}
        </p>
      </div>
      <div className="text-right shrink-0">
        <p className={`text-sm font-bold ${isIn ? "text-green-400" : "text-red-400"}`}>
          {isIn ? "+" : "-"}{maskAmount(parseFloat(pay.amount), v => `${CURRENCY} ${v.toLocaleString("en-IN")}`)}
        </p>
        <p className="text-[10px] text-navy-500">{isIn ? "Received" : "Paid"}</p>
      </div>
      <button
        onClick={() => onDelete(pay)}
        className="ml-2 rounded-lg p-1.5 text-navy-500 hover:bg-navy-700 hover:text-red-400 transition"
        title="Delete"
      >
        <X className="h-3.5 w-3.5" />
      </button>
    </div>
  );
}

/* ─── Main Page ─── */
export default function PaymentsPage() {
  const { t, language } = useTranslation();
  const maskAmount = usePrivateAmount();
  const bid = localStorage.getItem("business_id");

  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState("ALL");
  const [search, setSearch] = useState("");
  const [modal, setModal] = useState(null); // "IN" | "OUT" | null
  const [deleting, setDeleting] = useState(null);
  const [deleteError, setDeleteError] = useState("");
  const [searchParams, setSearchParams] = useSearchParams();

  // Alt+I / Alt+O (see useKeyboardShortcuts) land here as ?action=in|out —
  // open the matching modal once, then drop the param so a refresh or
  // browser-back doesn't keep reopening it.
  useEffect(() => {
    const action = searchParams.get("action");
    if (action === "in" || action === "out") {
      setModal(action.toUpperCase());
      setSearchParams((prev) => { prev.delete("action"); return prev; }, { replace: true });
    }
  }, [searchParams, setSearchParams]);

  const load = () => {
    setLoading(true);
    partiesApi.payments({ business: bid, page_size: 1000 })
      .then(r => setPayments(r.data.results ?? r.data))
      .catch(() => setPayments([]))
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  // Stats
  const totalIn = payments.filter(p => p.payment_type === "IN").reduce((s, p) => s + parseFloat(p.amount), 0);
  const totalOut = payments.filter(p => p.payment_type === "OUT").reduce((s, p) => s + parseFloat(p.amount), 0);
  const thisMonth = new Date().toISOString().slice(0, 7);
  const monthIn = payments.filter(p => p.payment_type === "IN" && (p.date || "").startsWith(thisMonth))
    .reduce((s, p) => s + parseFloat(p.amount), 0);

  const TABS = [
    { key: "ALL", label: "All" },
    { key: "IN",  label: "Received" },
    { key: "OUT", label: "Paid Out" },
  ];

  const filtered = payments.filter(p => {
    const matchTab = tab === "ALL" || p.payment_type === tab;
    const q = search.toLowerCase();
    const matchSearch = !q || (p.party_name || "").toLowerCase().includes(q) || (p.note || "").toLowerCase().includes(q);
    return matchTab && matchSearch;
  });

  const handleDelete = async () => {
    setDeleteError("");
    try {
      await partiesApi.deletePayment(deleting.id);
      setPayments(prev => prev.filter(p => p.id !== deleting.id));
    } catch (err) {
      setDeleteError(err.response?.data?.error || err.response?.data?.detail || "Could not delete this payment.");
    }
    setDeleting(null);
  };

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">{t("payments")}</h1>
          <p className="mt-0.5 text-sm text-navy-500">
            {language === "ne" ? "भुक्तानी प्राप्त र भुक्तानी गरेको रेकर्ड" : "Record payments received and payments made"}
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setModal("IN")}
            className="flex items-center gap-2 rounded-xl bg-green-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-green-700 transition"
          >
            <ArrowDownLeft className="h-4 w-4" />
            {language === "ne" ? "पाउनुपर्ने" : "To Receive"}
          </button>
          <button
            onClick={() => setModal("OUT")}
            className="flex items-center gap-2 rounded-xl bg-red-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-red-600 transition"
          >
            <ArrowUpRight className="h-4 w-4" />
            {language === "ne" ? "दिनुपर्ने" : "To Give"}
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-green-500/10">
              <ArrowDownLeft className="h-4 w-4 text-green-400" />
            </div>
            <p className="text-xs text-navy-400">Total Received</p>
          </div>
          <p className="text-xl font-bold text-green-400">
            {maskAmount(totalIn, v => `${CURRENCY} ${Math.round(v).toLocaleString("en-IN")}`)}
          </p>
        </div>
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-red-500/10">
              <ArrowUpRight className="h-4 w-4 text-red-400" />
            </div>
            <p className="text-xs text-navy-400">Total Paid Out</p>
          </div>
          <p className="text-xl font-bold text-red-400">
            {maskAmount(totalOut, v => `${CURRENCY} ${Math.round(v).toLocaleString("en-IN")}`)}
          </p>
        </div>
        <div className="col-span-2 sm:col-span-1 rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-orange-500/10">
              <Wallet className="h-4 w-4 text-orange-500" />
            </div>
            <p className="text-xs text-navy-400">This Month In</p>
          </div>
          <p className="text-xl font-bold text-orange-400">
            {maskAmount(monthIn, v => `${CURRENCY} ${Math.round(v).toLocaleString("en-IN")}`)}
          </p>
        </div>
      </div>

      {deleteError && (
        <div className="flex items-center justify-between gap-2 rounded-xl border border-red-500/20 bg-red-500/5 px-3 py-2 text-xs text-red-400">
          <span className="flex items-center gap-2"><AlertTriangle className="h-3.5 w-3.5 shrink-0" /> {deleteError}</span>
          <button onClick={() => setDeleteError("")}><X className="h-3.5 w-3.5" /></button>
        </div>
      )}

      {/* Tabs + Search */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <TabBar tabs={TABS} active={tab} onChange={setTab} />
        <SearchBar value={search} onChange={setSearch} placeholder="Search party, note…" className="sm:w-56" />
      </div>

      {/* List */}
      <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
        {/* Table header */}
        <div className="hidden sm:grid grid-cols-12 gap-2 border-b border-navy-800 bg-navy-900/80 px-4 py-2.5 text-xs font-semibold text-navy-500">
          <div className="col-span-1">Type</div>
          <div className="col-span-3">Party</div>
          <div className="col-span-2">Date</div>
          <div className="col-span-2">Method</div>
          <div className="col-span-2">Note</div>
          <div className="col-span-1 text-right">Amount</div>
          <div className="col-span-1"></div>
        </div>
        {loading ? (
          <LoadingSpinner />
        ) : filtered.length === 0 ? (
          <EmptyState
            icon={Wallet}
            title="No payments yet"
            description="Record payments received from customers or paid to suppliers."
            actionLabel="Record Payment In"
            onAction={() => setModal("IN")}
          />
        ) : (
          filtered.map(pay => (
            <PaymentRow key={pay.id} pay={pay} onDelete={setDeleting} />
          ))
        )}
      </div>

      {/* Modals */}
      {modal && (
        <PaymentModal
          type={modal}
          onClose={() => setModal(null)}
          onSaved={() => { setModal(null); load(); }}
        />
      )}
      {deleting && (
        <ConfirmDialog
          message={`Delete this payment of ${CURRENCY} ${parseFloat(deleting.amount).toLocaleString()} from ${deleting.party_name}? It will move to Recycle Bin and the related invoice/bill balance will be restored — you can undo this from there.`}
          onConfirm={handleDelete}
          onCancel={() => setDeleting(null)}
        />
      )}
    </div>
  );
}
