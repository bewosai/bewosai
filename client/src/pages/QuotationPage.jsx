import { useState, useEffect } from "react";
import { sales, parties as partiesApi } from "../api/index";
import { useTranslation } from "../utils/translations";
import { useDateFormat, useAppSettings } from "../context/AppSettingsContext";
import { useAuth } from "../context/AuthContext";
import { FileText, Plus, Loader, X, AlertCircle, Edit2, Trash2, ChevronDown, Printer } from "lucide-react";
import ConfirmDialog from "../components/common/ConfirmDialog";
import { adToBS, formatBS } from "../utils/nepaliDate";
import { amountInWords } from "../utils/amountInWords";

const today = () => new Date().toISOString().slice(0, 10);
const F = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500 transition";

const STATUS_STYLES = {
  DRAFT:    "bg-navy-800 text-navy-400",
  SENT:     "bg-blue-500/10 text-blue-400",
  ACCEPTED: "bg-green-500/10 text-green-400",
  REJECTED: "bg-red-500/10 text-red-400",
};

/* ─── Print Modal ─── */
function QuotationPrintModal({ quotation, onClose }) {
  const { language } = useAppSettings();
  const { currentBusiness } = useAuth();
  const businessName = localStorage.getItem("business_name") || "Business Name";
  const businessAddress = localStorage.getItem("business_address") || "";
  const businessPhone = localStorage.getItem("business_phone") || "";
  const businessLogo = localStorage.getItem("business_logo") || null;
  const businessPan = currentBusiness?.pan_number || "";
  const footerText = localStorage.getItem("invoice_footer_text") || "Thank you for your business!";

  const subtotal = parseFloat(quotation.subtotal || 0);
  const discount = parseFloat(quotation.discount || 0);
  const total = parseFloat(quotation.total || 0);
  const miti = quotation.date ? formatBS(adToBS(new Date(quotation.date))) : "";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-2xl bg-[#ffffff] text-gray-800 shadow-2xl print:max-h-none print:overflow-visible print:shadow-none print:rounded-none">
        <div className="flex items-center justify-between border-b p-4 print:hidden">
          <span className="font-bold text-gray-900">Print Quotation</span>
          <div className="flex items-center gap-3">
            <button onClick={() => window.print()} className="rounded-lg bg-orange-500 px-4 py-2 text-sm text-white hover:bg-orange-600">
              <Printer size={14} className="mr-1 inline" /> Print
            </button>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-700"><X size={20} /></button>
          </div>
        </div>

        <div className="p-8 print:p-4 text-gray-800" id="print-area">
          <div className="mb-5 flex items-start justify-between gap-3">
            <div>
              <h2 className="text-2xl font-bold text-gray-900">{businessName}</h2>
              <p className="text-xs text-gray-600 mt-0.5">
                {businessPhone}{businessPhone && businessAddress ? "• " : ""}{businessAddress}
              </p>
              {businessPan && <p className="text-xs text-gray-600">PAN No: {businessPan}</p>}
            </div>
            {businessLogo && <img src={businessLogo} alt="logo" className="h-14 w-14 rounded-lg object-cover border" />}
          </div>

          <h3 className="mb-5 text-center text-xl font-bold uppercase tracking-wide text-gray-900">
            Quotation
          </h3>

          <div className="mb-5 grid grid-cols-2 gap-4 text-sm">
            <div>
              <p className="text-gray-500">Customer:</p>
              <p className="font-semibold text-gray-900">{quotation.customer_name || "—"}</p>
            </div>
            <div className="text-right text-xs space-y-0.5">
              <p className="text-gray-500">Quotation No: <span className="font-semibold text-gray-900">{quotation.quotation_number}</span></p>
              <p className="text-gray-500">Date: <span className="font-semibold text-gray-900">{quotation.date}</span></p>
              {miti && <p className="text-gray-500">Miti: <span className="font-semibold text-gray-900">{miti}</span></p>}
              {quotation.expiry_date && <p className="text-gray-500">Valid Until: <span className="font-semibold text-gray-900">{quotation.expiry_date}</span></p>}
              <p className="text-gray-500">Status: <span className="font-semibold text-gray-900">{quotation.status}</span></p>
            </div>
          </div>

          <div className="mb-2 grid grid-cols-2 gap-6">
            <div className="text-sm">
              <p className="font-semibold text-gray-700">Amount in Words</p>
              <p className="text-gray-600">{amountInWords(total)}</p>
              <p className="mt-2 text-xs italic text-gray-500">*Proforma Invoice</p>
            </div>
            <div className="space-y-1.5 text-sm">
              <div className="flex justify-between"><span className="text-gray-500">Subtotal:</span><span>Rs. {subtotal.toFixed(2)}</span></div>
              {discount > 0 && (
                <div className="flex justify-between text-red-500"><span>Discount:</span><span>- Rs. {discount.toFixed(2)}</span></div>
              )}
              <div className="flex justify-between border-t border-gray-300 pt-2 text-lg font-bold"><span>Total</span><span>Rs. {total.toFixed(2)}</span></div>
            </div>
          </div>

          {quotation.notes && (
            <div className="mt-4 text-xs text-gray-500 border-t pt-2">Notes: {quotation.notes}</div>
          )}

          <div className="mt-10 flex justify-end">
            <div className="text-center">
              <div className="h-14 w-40 border-b border-gray-400" />
              <p className="mt-1 text-xs text-gray-600">Authorized Signature</p>
            </div>
          </div>

          {footerText && (
            <div className="mt-4 border-t pt-3 text-center text-xs text-gray-400 italic">{footerText}</div>
          )}
        </div>
      </div>
    </div>
  );
}

function QuotationModal({ initial, onClose, onSaved }) {
  const { language } = useTranslation();
  const bid = localStorage.getItem("business_id");
  const [form, setForm] = useState({
    customer: initial?.customer ?? "",
    date: initial?.date ?? today(),
    expiry_date: initial?.expiry_date ?? "",
    subtotal: initial?.subtotal ?? "",
    discount: initial?.subtotal && parseFloat(initial.subtotal) > 0
      ? String(Math.round((parseFloat(initial?.discount || 0) / parseFloat(initial.subtotal)) * 10000) / 100)
      : (initial?.discount ?? "0"),
    total: initial?.total ?? "",
    status: initial?.status ?? "DRAFT",
    notes: initial?.notes ?? "",
  });
  const [customers, setCustomers] = useState([]);
  const [customerSearch, setCustomerSearch] = useState(initial?.customer_name ?? "");
  const [showDrop, setShowDrop] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    partiesApi.list({ business: bid, party_type: "CUSTOMER" })
      .then(r => setCustomers(r.data.results ?? r.data))
      .catch(() => {});
    partiesApi.list({ business: bid, party_type: "BOTH" })
      .then(r => setCustomers(prev => {
        const ids = new Set(prev.map(p => p.id));
        return [...prev, ...(r.data.results ?? r.data).filter(p => !ids.has(p.id))];
      }))
      .catch(() => {});
  }, []);

  const filtered = customers.filter(c =>
    c.name.toLowerCase().includes(customerSearch.toLowerCase())
  );

  // Auto-calc total when subtotal or discount % changes
  const handleSubtotal = (val) => {
    const sub = parseFloat(val) || 0;
    const pct = Math.min(100, Math.max(0, parseFloat(form.discount) || 0));
    const dis = sub * pct / 100;
    setForm(f => ({ ...f, subtotal: val, total: String(Math.max(0, sub - dis)) }));
  };
  const handleDiscount = (val) => {
    const sub = parseFloat(form.subtotal) || 0;
    const pct = Math.min(100, Math.max(0, parseFloat(val) || 0));
    const dis = sub * pct / 100;
    setForm(f => ({ ...f, discount: val, total: String(Math.max(0, sub - dis)) }));
  };

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    if (!form.date) { setError("Date is required."); return; }
    if (!form.total) { setError("Total amount is required."); return; }
    setSaving(true);
    try {
      const subtotalNum = parseFloat(form.subtotal) || 0;
      const discountPct = Math.min(100, Math.max(0, parseFloat(form.discount) || 0));
      const payload = {
        ...form,
        customer: form.customer || null,
        subtotal: subtotalNum,
        discount: (subtotalNum * discountPct / 100).toFixed(2),
        total: parseFloat(form.total) || 0,
        business: bid,
      };
      if (initial?.id) {
        await sales.updateQuotation(initial.id, payload);
      } else {
        await sales.createQuotation(payload);
      }
      onSaved();
    } catch (e) {
      setError(e.response?.data?.detail || Object.values(e.response?.data || {})?.[0]?.[0] || "Failed to save.");
    } finally { setSaving(false); }
  };

  const STATUSES = ["DRAFT", "SENT", "ACCEPTED", "REJECTED"];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-lg rounded-2xl border border-navy-700 bg-navy-900 p-6 max-h-[90vh] overflow-y-auto shadow-2xl">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{initial?.id ? "Edit Quotation" : "New Quotation"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {error && (
          <div className="mb-3 flex items-center gap-2 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">
            <AlertCircle className="h-4 w-4 shrink-0" /> {error}
          </div>
        )}
        <form onSubmit={submit} className="space-y-3">
          {/* Customer */}
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Customer (optional)</label>
            <div className="relative">
              <input className={F} placeholder="Search customer…"
                value={customerSearch}
                onChange={e => { setCustomerSearch(e.target.value); setShowDrop(true); setForm(f => ({ ...f, customer: "" })); }}
                onFocus={() => setShowDrop(true)} onBlur={() => setTimeout(() => setShowDrop(false), 150)}
              />
              {showDrop && filtered.length > 0 && (
                <div className="absolute z-10 mt-1 w-full rounded-xl border border-navy-700 bg-navy-900 shadow-xl max-h-48 overflow-y-auto">
                  {filtered.slice(0, 20).map(c => (
                    <button key={c.id} type="button"
                      className="w-full px-3 py-2.5 text-left text-sm text-white hover:bg-navy-800"
                      onMouseDown={() => { setForm(f => ({ ...f, customer: c.id })); setCustomerSearch(c.name); setShowDrop(false); }}
                    >
                      {c.name}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Dates */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Date *</label>
              <input type="date" className={F} value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Expiry Date</label>
              <input type="date" className={F} value={form.expiry_date} onChange={e => setForm(f => ({ ...f, expiry_date: e.target.value }))} />
            </div>
          </div>

          {/* Amounts */}
          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Subtotal</label>
              <input type="number" min="0" step="0.01" className={F} placeholder="0.00"
                value={form.subtotal} onChange={e => handleSubtotal(e.target.value)} />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Discount (%)</label>
              <input type="number" min="0" max="100" step="0.01" className={F} placeholder="0"
                value={form.discount} onChange={e => handleDiscount(e.target.value)} />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Total *</label>
              <input type="number" min="0" step="0.01" className={F} placeholder="0.00"
                value={form.total} onChange={e => setForm(f => ({ ...f, total: e.target.value }))} />
            </div>
          </div>

          {/* Status */}
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Status</label>
            <div className="flex gap-2 flex-wrap">
              {STATUSES.map(s => (
                <button key={s} type="button"
                  onClick={() => setForm(f => ({ ...f, status: s }))}
                  className={`rounded-lg px-3 py-1.5 text-xs font-medium transition border ${
                    form.status === s
                      ? "border-orange-500 bg-orange-500/10 text-orange-400"
                      : "border-navy-700 text-navy-400 hover:text-white"
                  }`}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>

          {/* Notes */}
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Notes</label>
            <textarea rows={2} className={`${F} resize-none`} placeholder="Optional notes…"
              value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} />
          </div>

          <div className="flex gap-3 pt-1">
            <button type="submit" disabled={saving}
              className="flex-1 rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition disabled:opacity-50">
              {saving ? "Saving…" : (initial?.id ? "Save Changes" : "Create Quotation")}
            </button>
            <button type="button" onClick={onClose}
              className="rounded-xl border border-navy-700 px-4 py-2.5 text-sm text-navy-400 hover:bg-navy-800">
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function QuotationPage() {
  const { t, language } = useTranslation();
  const formatDate = useDateFormat();
  const [quotations, setQuotations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("ALL");
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [deleting, setDeleting] = useState(null);
  const [printing, setPrinting] = useState(null);

  const load = () => {
    setLoading(true);
    sales.quotations().then(r => setQuotations(r.data?.results ?? r.data ?? [])).catch(() => setQuotations([])).finally(() => setLoading(false));
  };

  useEffect(load, []);

  const handleDelete = async () => {
    try { await sales.deleteQuotation(deleting.id); } catch {}
    setQuotations(prev => prev.filter(q => q.id !== deleting.id));
    setDeleting(null);
  };

  const tabs = ["ALL", "DRAFT", "SENT", "ACCEPTED", "REJECTED"];
  const filtered = activeTab === "ALL" ? quotations : quotations.filter(q => q.status === activeTab);

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold text-white">
            <FileText className="h-6 w-6 text-orange-500" />{t("quotation")}
          </h1>
          <p className="mt-1 text-sm text-navy-500">{t("quotationHistory")}</p>
        </div>
        <button
          onClick={() => { setEditing(null); setShowModal(true); }}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition"
        >
          <Plus className="h-4 w-4" />{t("newQuotation")}
        </button>
      </div>

      <div className="flex gap-2 flex-wrap">
        {tabs.map(tab => (
          <button key={tab} onClick={() => setActiveTab(tab)}
            className={`rounded-xl px-4 py-2 text-sm font-medium transition ${activeTab === tab ? "bg-orange-500 text-white" : "bg-navy-900 border border-navy-800 text-navy-400 hover:text-white"}`}>
            {tab === "ALL" ? t("all") : tab}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center rounded-2xl border border-navy-800 bg-navy-900 py-16 text-center">
          <FileText className="h-10 w-10 text-navy-600 mb-3" />
          <h3 className="font-semibold text-white">{t("noData")}</h3>
          <p className="mt-2 text-sm text-navy-500">{language === "ne" ? "नयाँ कोटेशन सिर्जना गर्नुहोस्" : "Create your first quotation"}</p>
          <button onClick={() => { setEditing(null); setShowModal(true); }}
            className="mt-4 flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600 transition">
            <Plus className="h-4 w-4" /> {t("newQuotation")}
          </button>
        </div>
      ) : (
        <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="divide-y divide-navy-800">
            {filtered.map(q => (
              <div key={q.id}
                onClick={() => { setEditing(q); setShowModal(true); }}
                className="flex items-center gap-4 px-5 py-4 hover:bg-navy-800/40 transition cursor-pointer">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="font-semibold text-white text-sm">{q.quotation_number}</p>
                    <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${STATUS_STYLES[q.status] || STATUS_STYLES.DRAFT}`}>{q.status}</span>
                  </div>
                  <p className="text-xs text-navy-500 mt-0.5">
                    {q.customer_name || (language === "ne" ? "ग्राहक छैन" : "No customer")} · {formatDate(q.date)}
                    {q.expiry_date && ` · expires ${formatDate(q.expiry_date)}`}
                  </p>
                </div>
                <div className="text-right shrink-0 mr-2">
                  <p className="font-bold text-white">Rs. {parseFloat(q.total || 0).toLocaleString("en-IN", { minimumFractionDigits: 2 })}</p>
                  {parseFloat(q.discount) > 0 && (
                    <p className="text-xs text-green-400">-Rs. {parseFloat(q.discount).toLocaleString("en-IN")} off</p>
                  )}
                </div>
                <div className="flex gap-1.5 shrink-0">
                  <button onClick={(e) => { e.stopPropagation(); setPrinting(q); }}
                    className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-blue-500/50 hover:text-blue-400 transition">
                    <Printer className="h-3.5 w-3.5" />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); setEditing(q); setShowModal(true); }}
                    className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-orange-500/50 hover:text-orange-400 transition">
                    <Edit2 className="h-3.5 w-3.5" />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); setDeleting(q); }}
                    className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-red-500/50 hover:text-red-400 transition">
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {showModal && (
        <QuotationModal
          initial={editing}
          onClose={() => { setShowModal(false); setEditing(null); }}
          onSaved={() => { setShowModal(false); setEditing(null); load(); }}
        />
      )}
      {printing && <QuotationPrintModal quotation={printing} onClose={() => setPrinting(null)} />}
      {deleting && (
        <ConfirmDialog
          message={`Delete quotation "${deleting.quotation_number}"? This cannot be undone.`}
          onConfirm={handleDelete}
          onCancel={() => setDeleting(null)}
        />
      )}
    </div>
  );
}
