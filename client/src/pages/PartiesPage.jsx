import { useEffect, useState, useMemo } from "react";
import { useAuth } from "../context/AuthContext";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount } from "../context/AppSettingsContext";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { parties as partiesApi } from "../api";
import {
  Users, UserCheck, Truck, Plus, Search, X, ChevronRight,
  Phone, Mail, MapPin, TrendingUp, TrendingDown, DollarSign,
  Edit2, Trash2,
} from "lucide-react";

/* ── helpers ── */
const TYPE_META = {
  CUSTOMER: { label: "Customer", icon: UserCheck, color: "text-green-400 bg-green-500/10 border-green-500/20" },
  SUPPLIER: { label: "Supplier", icon: Truck,     color: "text-blue-400  bg-blue-500/10  border-blue-500/20"  },
  BOTH:     { label: "Both",     icon: Users,      color: "text-orange-400 bg-orange-500/10 border-orange-500/20" },
};

/* ── Party form modal ── */
function PartyModal({ initial, onClose, onSaved }) {
  const { t } = useTranslation();
  const [form, setForm] = useState({
    name: "", party_type: "CUSTOMER", phone: "", email: "",
    address: "", opening_balance: "0", notes: "",
    ...initial,
  });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");

  const f = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";
  const bid = localStorage.getItem("business_id");

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setErr("Name is required."); return; }
    setSaving(true);
    try {
      if (initial?.id) {
        await partiesApi.update(initial.id, form);
      } else {
        await partiesApi.create({ ...form, business: bid });
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
          <input type="number" value={form.opening_balance} onChange={(e) => setForm({ ...form, opening_balance: e.target.value })}
            placeholder="Opening Balance" className={f} />
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
function PartyCard({ party, onEdit, onDelete }) {
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
            {balance > 0 ? "Receivable" : balance < 0 ? "Payable" : "Settled"}
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
        <button onClick={() => onEdit(party)}
          className="flex flex-1 items-center justify-center gap-1.5 rounded-xl border border-navy-700 py-1.5 text-xs text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400">
          <Edit2 className="h-3 w-3" /> Edit
        </button>
        <button onClick={() => onDelete(party)}
          className="flex items-center justify-center gap-1.5 rounded-xl border border-navy-700 px-3 py-1.5 text-xs text-navy-300 transition hover:border-red-500/50 hover:text-red-400">
          <Trash2 className="h-3 w-3" />
        </button>
      </div>
    </div>
  );
}

/* ── Main page ── */
export default function PartiesPage() {
  const { currentBusiness } = useAuth();
  const { t } = useTranslation();
  const maskAmount = usePrivateAmount();

  const [parties, setParties] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState("ALL");
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);

  const load = () => {
    setLoading(true);
    partiesApi.list({ business: currentBusiness?.id })
      .then((r) => setParties(r.data.results ?? r.data))
      .finally(() => setLoading(false));
  };

  useEffect(() => { if (currentBusiness?.id) load(); }, [currentBusiness?.id]);

  const handleDelete = async (party) => {
    if (!window.confirm(`Delete "${party.name}"?`)) return;
    await partiesApi.delete(party.id);
    load();
  };

  const filtered = useMemo(() => {
    let list = parties;
    if (typeFilter !== "ALL") list = list.filter((p) => p.party_type === typeFilter);
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
    { key: "CUSTOMER", label: t("mod_parties").replace("Party","") + "Customers", count: stats.customers },
    { key: "SUPPLIER", label: "Suppliers",    count: stats.suppliers },
    { key: "BOTH",     label: "Both",         count: parties.filter(p => p.party_type === "BOTH").length },
  ];

  return (
    <div>
      <PageHeader
        title={t("parties")}
        subtitle="Manage customers, suppliers, and track balances."
        action={
          <PrimaryButton onClick={() => { setEditing(null); setShowModal(true); }}>
            <Plus className="h-4 w-4" /> Add Party
          </PrimaryButton>
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
            <p className="text-xs text-navy-400">Receivable</p>
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
              onDelete={handleDelete}
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
    </div>
  );
}
