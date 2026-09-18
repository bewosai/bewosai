import { useEffect, useState, useMemo } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import * as XLSX from "xlsx";
import { useAuth } from "../context/AuthContext";
import { useEscToClose } from "../hooks/useEscToClose";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount } from "../context/AppSettingsContext";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import Modal from "../components/common/Modal";
import ConfirmDialog from "../components/common/ConfirmDialog";
import LoadingSpinner from "../components/common/LoadingSpinner";
import SearchBar from "../components/common/SearchBar";
import TabBar from "../components/common/TabBar";
import { parties as partiesApi } from "../api";
import { CURRENCY } from "../constants";
import {
  Users, UserCheck, Truck, Plus, Search, X, ChevronRight,
  Phone, Mail, MapPin, TrendingUp, TrendingDown, DollarSign,
  Edit2, Trash2, BookOpen, ArrowDownLeft, ArrowUpRight,
  ShoppingCart, Package, Loader, Upload, Download,
} from "lucide-react";
import { todayStr } from "../utils/dates";

/* ── Export current parties to .xlsx — same columns the bulk-import
   template uses, so an exported file can be edited and re-imported. ── */
function exportPartiesToExcel(parties) {
  const headers = ["name", "party_type", "phone", "email", "address", "opening_balance"];
  const rows = parties.map(p => [
    p.name, p.party_type, p.phone || "", p.email || "", p.address || "", p.opening_balance ?? 0,
  ]);
  const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
  ws["!cols"] = headers.map(() => ({ wch: 20 }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Parties");
  XLSX.writeFile(wb, `parties_export_${todayStr()}.xlsx`);
}

/* ── helpers ── */
const TYPE_META = {
  CUSTOMER: { label: "Customer", icon: UserCheck, color: "text-green-400 bg-green-500/10 border-green-500/20" },
  SUPPLIER: { label: "Supplier", icon: Truck,     color: "text-blue-400  bg-blue-500/10  border-blue-500/20"  },
  BOTH:     { label: "Both",     icon: Users,      color: "text-orange-400 bg-orange-500/10 border-orange-500/20" },
};

/* ── Party form modal ── */
function PartyModal({ initial, onClose, onSaved }) {
  useEscToClose(onClose);
  const { t } = useTranslation();
  const initialBalance = Number(initial?.opening_balance ?? 0);
  const [form, setForm] = useState({
    name: "", party_type: "CUSTOMER", phone: "", email: "",
    address: "", notes: "",
    ...initial,
    // Stored/edited as an always-positive amount + direction rather than a
    // signed number — entering "-500" to mean "I owe them" isn't obvious,
    // so the sign is derived from obDirection at submit time instead.
    opening_balance: Math.abs(initialBalance) || "",
  });
  // "To Receive" (they owe us, positive) vs "To Give" (we owe them,
  // negative) — matches the wording already used on the party balance card.
  const [obDirection, setObDirection] = useState(initialBalance < 0 ? "PAYABLE" : "RECEIVABLE");
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");

  const f = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";
  const bid = localStorage.getItem("business_id");

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setErr("Name is required."); return; }
    setSaving(true);
    const signedBalance = obDirection === "PAYABLE"
      ? -Math.abs(Number(form.opening_balance) || 0)
      : Math.abs(Number(form.opening_balance) || 0);
    const payload = { ...form, opening_balance: signedBalance };
    try {
      if (initial?.id) {
        await partiesApi.update(initial.id, payload);
      } else {
        await partiesApi.create({ ...payload, business: bid });
      }
      onSaved();
    } catch (er) {
      setErr(er.response?.data?.name?.[0] || "Failed to save party.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-lg rounded-2xl border border-navy-700 bg-navy-900 p-6 max-h-[90vh] overflow-y-auto">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{initial?.id ? "Edit Party" : t("add") + " Party"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {err && <p className="mb-3 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}
        <form onSubmit={submit} className="space-y-3">
          <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder={`${t("name")} *`} className={f} />

          {/* Party type selector */}
          <div>
            <p className="mb-1.5 text-xs text-navy-400">{t("type")}</p>
            <div className="grid grid-cols-3 gap-2">
              {Object.entries(TYPE_META).map(([key, meta]) => {
                const Icon = meta.icon;
                return (
                  <button key={key} type="button"
                    onClick={() => setForm({ ...form, party_type: key })}
                    className={`flex flex-col items-center gap-1 rounded-xl border p-2.5 text-center transition ${
                      form.party_type === key ? "border-orange-500 bg-orange-500/10" : "border-navy-700 bg-navy-950 hover:border-navy-600"
                    }`}
                  >
                    <Icon className={`h-5 w-5 ${form.party_type === key ? "text-orange-400" : "text-navy-400"}`} />
                    <span className="text-xs font-medium text-white">{meta.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })}
              placeholder={t("phone")} className={f} />
            <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })}
              placeholder={t("email")} className={f} />
          </div>
          <input value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })}
            placeholder={t("address")} className={f} />

          {/* Opening balance: an always-positive amount + explicit direction,
              so the user never has to guess that a negative number means
              "I owe them" — this becomes the sign on opening_balance. */}
          <div>
            <p className="mb-1.5 text-xs text-navy-400">Opening Balance</p>
            <div className="flex gap-2">
              <input type="number" min="0" step="0.01" value={form.opening_balance}
                onChange={(e) => setForm({ ...form, opening_balance: e.target.value })}
                placeholder="0.00" className={`${f} flex-1`} />
              <div className="grid shrink-0 grid-cols-2 gap-1.5">
                <button type="button" onClick={() => setObDirection("RECEIVABLE")}
                  className={`rounded-xl border px-3 py-2 text-xs font-semibold transition ${
                    obDirection === "RECEIVABLE" ? "border-red-500 bg-red-500/10 text-red-400" : "border-navy-700 bg-navy-950 text-navy-400 hover:border-navy-600"
                  }`}
                >
                  To Receive
                </button>
                <button type="button" onClick={() => setObDirection("PAYABLE")}
                  className={`rounded-xl border px-3 py-2 text-xs font-semibold transition ${
                    obDirection === "PAYABLE" ? "border-green-500 bg-green-500/10 text-green-400" : "border-navy-700 bg-navy-950 text-navy-400 hover:border-navy-600"
                  }`}
                >
                  To Give
                </button>
              </div>
            </div>
          </div>

          <textarea value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })}
            placeholder={t("note")} rows={2} className={`${f} resize-none`} />

          <div className="flex gap-3 pt-1">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>
              {saving ? "Saving…" : t("save")}
            </PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>{t("cancel")}</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ── Party card (responsive: full detail on desktop, compact on mobile) ── */
function PartyCard({ party, onEdit, onDelete, onLedger }) {
  const maskAmount = usePrivateAmount();
  const meta = TYPE_META[party.party_type] || TYPE_META.CUSTOMER;
  const Icon = meta.icon;
  const balance = parseFloat(party.balance ?? party.opening_balance ?? 0);
  const balanceLabel = maskAmount(Math.abs(balance), (v) => `Rs. ${v.toLocaleString()}`);

  return (
    <div className="group rounded-2xl border border-navy-800 bg-navy-900 p-4 transition hover:border-navy-700">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-3 min-w-0">
          <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border ${meta.color}`}>
            <Icon className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <p className="truncate font-semibold text-white">{party.name}</p>
            <span className={`mt-0.5 inline-block rounded-lg border px-2 py-0.5 text-[10px] font-semibold ${meta.color}`}>
              {meta.label}
            </span>
          </div>
        </div>
        <div className="shrink-0 text-right">
          <p className={`text-sm font-bold ${balance > 0 ? "text-red-400" : balance < 0 ? "text-green-400" : "text-navy-400"}`}>
            {balanceLabel}
          </p>
          <p className="text-[10px] text-navy-500">
            {balance > 0 ? "To Receive" : balance < 0 ? "To Give" : "Settled"}
          </p>
        </div>
      </div>

      {/* Contact info */}
      <div className="mt-3 space-y-1">
        {party.phone && (
          <div className="flex items-center gap-2 text-xs text-navy-400">
            <Phone className="h-3 w-3 shrink-0" /> <span className="truncate">{party.phone}</span>
          </div>
        )}
        {party.email && (
          <div className="flex items-center gap-2 text-xs text-navy-400">
            <Mail className="h-3 w-3 shrink-0" /> <span className="truncate">{party.email}</span>
          </div>
        )}
        {party.address && (
          <div className="flex items-center gap-2 text-xs text-navy-400">
            <MapPin className="h-3 w-3 shrink-0" /> <span className="truncate">{party.address}</span>
          </div>
        )}
      </div>

      {/* Actions */}
      <div className="mt-3 flex gap-2 border-t border-navy-800 pt-3">
        <button onClick={() => onLedger(party)}
          className="flex flex-1 items-center justify-center gap-1.5 rounded-xl border border-navy-700 py-1.5 text-xs text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400">
          <BookOpen className="h-3 w-3" /> Ledger
        </button>
        <button onClick={() => onEdit(party)}
          className="flex items-center justify-center gap-1.5 rounded-xl border border-navy-700 px-3 py-1.5 text-xs text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400">
          <Edit2 className="h-3 w-3" />
        </button>
        <button onClick={() => onDelete(party)}
          className="flex items-center justify-center gap-1.5 rounded-xl border border-navy-700 px-3 py-1.5 text-xs text-navy-300 transition hover:border-red-500/50 hover:text-red-400">
          <Trash2 className="h-3 w-3" />
        </button>
      </div>
    </div>
  );
}

/* ── Party Ledger Modal ── */
const ENTRY_META = {
  SALE:            { icon: ShoppingCart, label: "Invoice",         color: "text-blue-400",   bg: "bg-blue-500/10" },
  RECEIPT:         { icon: ArrowDownLeft, label: "Receipt",        color: "text-green-400",  bg: "bg-green-500/10" },
  PURCHASE:        { icon: Package,       label: "Purchase",       color: "text-purple-400", bg: "bg-purple-500/10" },
  PAYMENT:         { icon: ArrowUpRight,  label: "Payment",        color: "text-orange-400", bg: "bg-orange-500/10" },
  PAYMENT_IN:      { icon: ArrowDownLeft, label: "Payment In",     color: "text-green-400",  bg: "bg-green-500/10" },
  PAYMENT_OUT:     { icon: ArrowUpRight,  label: "Payment Out",    color: "text-red-400",    bg: "bg-red-500/10" },
  SALE_RETURN:     { icon: ShoppingCart,  label: "Sale Return",    color: "text-green-400",  bg: "bg-green-500/10" },
  PURCHASE_RETURN: { icon: Package,       label: "Purchase Return", color: "text-red-400",   bg: "bg-red-500/10" },
};

function LedgerModal({ party, onClose }) {
  const maskAmount = usePrivateAmount();
  const bid = localStorage.getItem("business_id");
  const [ledger, setLedger] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    partiesApi.ledger(party.id, { business: bid })
      .then(r => setLedger(r.data))
      .catch(() => setLedger(null))
      .finally(() => setLoading(false));
  }, [party.id]);

  const fmt = (v) => maskAmount(Math.abs(v), n => `${CURRENCY} ${n.toLocaleString("en-IN")}`);
  const balance = ledger?.closing_balance ?? 0;

  return (
    <Modal
      title={`Ledger — ${party.name}`}
      onClose={onClose}
      size="lg"
    >
      {loading ? (
        <LoadingSpinner />
      ) : !ledger ? (
        <p className="py-10 text-center text-sm text-navy-400">Failed to load ledger.</p>
      ) : (
        <div className="space-y-4">
          {/* Summary strip */}
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <div className="rounded-xl border border-navy-700 bg-navy-950 p-3 text-center">
              <p className="text-xs text-navy-400">Total Debit</p>
              <p className="mt-1 font-bold text-white">{fmt(ledger.total_debit)}</p>
            </div>
            <div className="rounded-xl border border-navy-700 bg-navy-950 p-3 text-center">
              <p className="text-xs text-navy-400">Total Credit</p>
              <p className="mt-1 font-bold text-white">{fmt(ledger.total_credit)}</p>
            </div>
            <div className={`rounded-xl border p-3 text-center ${balance > 0 ? "border-red-500/20 bg-red-500/5" : balance < 0 ? "border-green-500/20 bg-green-500/5" : "border-navy-700 bg-navy-950"}`}>
              <p className="text-xs text-navy-400">Balance</p>
              <p className={`mt-1 font-bold ${balance > 0 ? "text-red-400" : balance < 0 ? "text-green-400" : "text-navy-400"}`}>
                {balance !== 0 ? fmt(balance) : "Settled"}
              </p>
            </div>
          </div>

          {/* Ledger entries */}
          {ledger.entries.length === 0 ? (
            <p className="py-8 text-center text-sm text-navy-400">No transactions yet.</p>
          ) : (
            <div className="rounded-xl border border-navy-800 overflow-x-auto">
              {/* Header */}
              <div className="grid grid-cols-12 gap-2 bg-navy-800/60 px-4 py-2.5 text-xs font-semibold text-navy-400 min-w-140">
                <div className="col-span-2">Date</div>
                <div className="col-span-2">Type</div>
                <div className="col-span-3">Ref</div>
                <div className="col-span-2 text-right">Debit</div>
                <div className="col-span-2 text-right">Credit</div>
                <div className="col-span-1 text-right">Balance</div>
              </div>
              {ledger.entries.map((e, i) => {
                const meta = ENTRY_META[e.type] || ENTRY_META.SALE;
                const Icon = meta.icon;
                return (
                  <div key={i} className="grid grid-cols-12 gap-2 items-center border-t border-navy-800/50 px-4 py-2.5 hover:bg-navy-800/20 text-sm min-w-140">
                    <div className="col-span-2 text-xs text-navy-400">{e.date}</div>
                    <div className="col-span-2">
                      <div className={`inline-flex items-center gap-1 rounded-lg px-1.5 py-0.5 text-[10px] font-semibold ${meta.bg} ${meta.color}`}>
                        <Icon className="h-2.5 w-2.5" />{meta.label}
                      </div>
                    </div>
                    <div className="col-span-3 text-xs text-navy-300 truncate">
                      {e.ref}{e.note ? ` · ${e.note}` : ""}
                    </div>
                    <div className="col-span-2 text-right text-xs">
                      {e.debit > 0 ? <span className="text-red-400">+{fmt(e.debit)}</span> : "—"}
                    </div>
                    <div className="col-span-2 text-right text-xs">
                      {e.credit > 0 ? <span className="text-green-400">−{fmt(e.credit)}</span> : "—"}
                    </div>
                    <div className={`col-span-1 text-right text-xs font-semibold ${e.balance > 0 ? "text-red-400" : e.balance < 0 ? "text-green-400" : "text-navy-400"}`}>
                      {fmt(e.balance)}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </Modal>
  );
}

/* ── Main page ── */
export default function PartiesPage() {
  const { currentBusiness } = useAuth();
  const { t } = useTranslation();
  const maskAmount = usePrivateAmount();
  const navigate = useNavigate();

  const [parties, setParties] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState("ALL");
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [ledgerParty, setLedgerParty] = useState(null);
  const [deletingParty, setDeletingParty] = useState(null);
  const [deleteError, setDeleteError] = useState("");
  const [searchParams, setSearchParams] = useSearchParams();

  // Alt+N (see useKeyboardShortcuts) lands here as ?action=add.
  useEffect(() => {
    if (searchParams.get("action") === "add") {
      setEditing(null);
      setShowModal(true);
      setSearchParams((prev) => { prev.delete("action"); return prev; }, { replace: true });
    }
  }, [searchParams, setSearchParams]);

  const load = () => {
    setLoading(true);
    partiesApi.list({ business: currentBusiness?.id, page_size: 1000 })
      .then((r) => setParties(r.data.results ?? r.data))
      .finally(() => setLoading(false));
  };

  useEffect(() => { if (currentBusiness?.id) load(); }, [currentBusiness?.id]);

  const handleDelete = async () => {
    setDeleteError("");
    try {
      await partiesApi.delete(deletingParty.id);
      setDeletingParty(null);
      load();
    } catch (err) {
      setDeleteError(err.response?.data?.error || "Failed to delete party.");
    }
  };

  const filtered = useMemo(() => {
    let list = parties;
    if (typeFilter === "CUSTOMER" || typeFilter === "SUPPLIER") {
      // A "Both" party counts toward Customers and Suppliers alike (see
      // stats.customers/suppliers below) — filter the same way so the tab's
      // own count badge always matches what it actually shows.
      list = list.filter((p) => p.party_type === typeFilter || p.party_type === "BOTH");
    } else if (typeFilter === "BOTH") {
      list = list.filter((p) => p.party_type === "BOTH");
    }
    if (search.trim()) {
      const q = search.toLowerCase();
      list = list.filter((p) =>
        [p.name, p.phone, p.email, p.address].filter(Boolean).join(" ").toLowerCase().includes(q)
      );
    }
    return list;
  }, [parties, typeFilter, search]);

  // Summary stats
  const stats = useMemo(() => {
    const customers = parties.filter((p) => p.party_type === "CUSTOMER" || p.party_type === "BOTH").length;
    const suppliers = parties.filter((p) => p.party_type === "SUPPLIER" || p.party_type === "BOTH").length;
    const totalReceivable = parties.reduce((s, p) => {
      const b = parseFloat(p.balance ?? p.opening_balance ?? 0);
      return s + (b > 0 ? b : 0);
    }, 0);
    const totalPayable = parties.reduce((s, p) => {
      const b = parseFloat(p.balance ?? p.opening_balance ?? 0);
      return s + (b < 0 ? Math.abs(b) : 0);
    }, 0);
    return { total: parties.length, customers, suppliers, totalReceivable, totalPayable };
  }, [parties]);

  const TABS = [
    { key: "ALL",      label: t("all"),       count: stats.total },
    { key: "CUSTOMER", label: "Customers",     count: stats.customers },
    { key: "SUPPLIER", label: "Suppliers",    count: stats.suppliers },
    { key: "BOTH",     label: "Both",         count: parties.filter(p => p.party_type === "BOTH").length },
  ];

  return (
    <div>
      <PageHeader
        title={t("parties")}
        subtitle="Manage customers, suppliers, and track balances."
        action={
          <div className="flex flex-wrap gap-2">
            <PrimaryButton variant="outline" onClick={() => exportPartiesToExcel(parties)} disabled={parties.length === 0}>
              <Download className="h-4 w-4" /> Export
            </PrimaryButton>
            <PrimaryButton variant="outline" onClick={() => navigate("/import?type=parties")}>
              <Upload className="h-4 w-4" /> Bulk Import
            </PrimaryButton>
            <PrimaryButton onClick={() => { setEditing(null); setShowModal(true); }}>
              <Plus className="h-4 w-4" /> Add Party
            </PrimaryButton>
          </div>
        }
      />

      {/* Summary cards */}
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <div className="flex items-center justify-between">
            <p className="text-xs text-navy-400">Total</p>
            <Users className="h-4 w-4 text-navy-500" />
          </div>
          <p className="mt-1.5 text-2xl font-bold text-white">{stats.total}</p>
        </div>
        <div className="rounded-2xl border border-green-500/20 bg-green-500/5 p-4">
          <div className="flex items-center justify-between">
            <p className="text-xs text-navy-400">Customers</p>
            <UserCheck className="h-4 w-4 text-green-400" />
          </div>
          <p className="mt-1.5 text-2xl font-bold text-green-400">{stats.customers}</p>
        </div>
        <div className="rounded-2xl border border-blue-500/20 bg-blue-500/5 p-4">
          <div className="flex items-center justify-between">
            <p className="text-xs text-navy-400">Suppliers</p>
            <Truck className="h-4 w-4 text-blue-400" />
          </div>
          <p className="mt-1.5 text-2xl font-bold text-blue-400">{stats.suppliers}</p>
        </div>
        <div className="rounded-2xl border border-orange-500/20 bg-orange-500/5 p-4">
          <div className="flex items-center justify-between">
            <p className="text-xs text-navy-400">To Receive</p>
            <TrendingUp className="h-4 w-4 text-orange-400" />
          </div>
          <p className="mt-1.5 text-xl font-bold text-orange-400">
            {maskAmount(stats.totalReceivable, (v) => `Rs. ${Math.round(v).toLocaleString()}`)}
          </p>
        </div>
      </div>

      {/* Filter tabs + search */}
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1 overflow-x-auto">
          {TABS.map(({ key, label, count }) => (
            <button key={key} onClick={() => setTypeFilter(key)}
              className={`flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
                typeFilter === key ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"
              }`}
            >
              {label}
              <span className={`rounded-full px-1.5 py-0.5 text-[10px] ${typeFilter === key ? "bg-white/20" : "bg-navy-800"}`}>
                {count}
              </span>
            </button>
          ))}
        </div>
        <div className="flex items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-2">
          <Search className="h-4 w-4 shrink-0 text-navy-500" />
          <input value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name, phone, email…"
            className="w-full min-w-0 bg-transparent text-sm text-white outline-none placeholder:text-navy-500" />
          {search && (
            <button onClick={() => setSearch("")}><X className="h-4 w-4 text-navy-400" /></button>
          )}
        </div>
      </div>

      {/* Party grid */}
      {loading ? (
        <div className="flex items-center justify-center py-16">
          <p className="text-sm text-navy-400">{t("loading")}</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center gap-4 rounded-2xl border border-dashed border-navy-700 py-16 text-center">
          <Users className="h-12 w-12 text-navy-700" />
          <p className="text-sm text-navy-400">
            {search || typeFilter !== "ALL" ? "No parties match your filter." : "No parties yet."}
          </p>
          {!search && typeFilter === "ALL" && (
            <PrimaryButton onClick={() => { setEditing(null); setShowModal(true); }}>
              <Plus className="h-4 w-4" /> Add First Party
            </PrimaryButton>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {filtered.map((party) => (
            <PartyCard
              key={party.id}
              party={party}
              onEdit={(p) => { setEditing(p); setShowModal(true); }}
              onDelete={(p) => { setDeleteError(""); setDeletingParty(p); }}
              onLedger={(p) => setLedgerParty(p)}
            />
          ))}
        </div>
      )}

      {showModal && (
        <PartyModal
          initial={editing}
          onClose={() => { setShowModal(false); setEditing(null); }}
          onSaved={() => { setShowModal(false); setEditing(null); load(); }}
        />
      )}
      {ledgerParty && (
        <LedgerModal party={ledgerParty} onClose={() => setLedgerParty(null)} />
      )}
      {deletingParty && (
        <ConfirmDialog
          message={
            deleteError ? (
              <span>
                <span className="mb-1.5 block text-red-400">{deleteError}</span>
                Delete "{deletingParty.name}"? This will remove all associated records.
              </span>
            ) : (
              `Delete "${deletingParty.name}"? This will remove all associated records.`
            )
          }
          onConfirm={handleDelete}
          onCancel={() => { setDeletingParty(null); setDeleteError(""); }}
        />
      )}
    </div>
  );
}
