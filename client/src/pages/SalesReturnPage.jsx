import { useState, useEffect } from "react";
import { sales } from "../api/index";
import { useTranslation } from "../utils/translations";
import { useAppSettings } from "../context/AppSettingsContext";
import { RotateCcw, Plus, Loader, X, AlertCircle } from "lucide-react";

const today = () => new Date().toISOString().slice(0, 10);
const F = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500 transition";

function ReturnModal({ onClose, onSaved }) {
  const { language } = useTranslation();
  const bid = localStorage.getItem("business_id");
  const [form, setForm] = useState({ original_sale: "", return_date: today(), reason: "", amount: "" });
  const [invoices, setInvoices] = useState([]);
  const [invoiceSearch, setInvoiceSearch] = useState("");
  const [showDrop, setShowDrop] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    sales.list({ business: bid }).then(r => setInvoices(r.data.results ?? r.data)).catch(() => {});
  }, []);

  const filteredInvoices = invoices.filter(inv =>
    inv.invoice_number.toLowerCase().includes(invoiceSearch.toLowerCase()) ||
    (inv.customer_name || "").toLowerCase().includes(invoiceSearch.toLowerCase())
  );

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    if (!form.original_sale) { setError("Select the original invoice."); return; }
    if (!form.amount || parseFloat(form.amount) <= 0) { setError("Enter a valid return amount."); return; }
    setSaving(true);
    try {
      await sales.createReturn({
        original_sale: form.original_sale,
        return_date: form.return_date,
        reason: form.reason,
        amount: parseFloat(form.amount),
        business: bid,
      });
      onSaved();
    } catch (e) {
      setError(e.response?.data?.detail || Object.values(e.response?.data || {})?.[0]?.[0] || "Failed to save.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6 shadow-2xl">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{language === "ne" ? "नयाँ फिर्ता" : "New Sales Return"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {error && (
          <div className="mb-3 flex items-center gap-2 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">
            <AlertCircle className="h-4 w-4 shrink-0" /> {error}
          </div>
        )}
        <form onSubmit={submit} className="space-y-3">
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">
              {language === "ne" ? "मूल इनभ्वाइस *" : "Original Invoice *"}
            </label>
            <div className="relative">
              <input className={F} placeholder="Search by invoice number or customer…"
                value={invoiceSearch}
                onChange={e => { setInvoiceSearch(e.target.value); setShowDrop(true); setForm(f => ({ ...f, original_sale: "" })); }}
                onFocus={() => setShowDrop(true)} onBlur={() => setTimeout(() => setShowDrop(false), 150)}
              />
              {showDrop && filteredInvoices.length > 0 && (
                <div className="absolute z-10 mt-1 w-full rounded-xl border border-navy-700 bg-navy-900 shadow-xl max-h-48 overflow-y-auto">
                  {filteredInvoices.slice(0, 20).map(inv => (
                    <button key={inv.id} type="button"
                      className="w-full px-3 py-2.5 text-left text-sm hover:bg-navy-800 flex items-center justify-between"
                      onMouseDown={() => {
                        setForm(f => ({ ...f, original_sale: inv.id, amount: String(inv.total) }));
                        setInvoiceSearch(`${inv.invoice_number}${inv.customer_name ? ` — ${inv.customer_name}` : ""}`);
                        setShowDrop(false);
                      }}
                    >
                      <span className="text-white">{inv.invoice_number}</span>
                      <span className="text-xs text-navy-400">{inv.customer_name || "—"} · Rs. {parseFloat(inv.total).toLocaleString()}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">
              {language === "ne" ? "फिर्ता मिति *" : "Return Date *"}
            </label>
            <input type="date" className={F} value={form.return_date}
              onChange={e => setForm(f => ({ ...f, return_date: e.target.value }))} />
          </div>

          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">
              {language === "ne" ? "फिर्ता रकम *" : "Return Amount *"}
            </label>
            <input type="number" min="0.01" step="0.01" className={F} placeholder="0.00"
              value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} />
          </div>

          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">
              {language === "ne" ? "कारण" : "Reason"}
            </label>
            <textarea rows={2} className={`${F} resize-none`}
              placeholder={language === "ne" ? "फिर्ताको कारण…" : "Reason for return…"}
              value={form.reason} onChange={e => setForm(f => ({ ...f, reason: e.target.value }))} />
          </div>

          <div className="flex gap-3 pt-1">
            <button type="submit" disabled={saving}
              className="flex-1 rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition disabled:opacity-50">
              {saving ? (language === "ne" ? "सुरक्षित…" : "Saving…") : (language === "ne" ? "फिर्ता दर्ता गर्नुहोस्" : "Record Return")}
            </button>
            <button type="button" onClick={onClose}
              className="rounded-xl border border-navy-700 px-4 py-2.5 text-sm text-navy-400 hover:bg-navy-800">
              {language === "ne" ? "रद्द" : "Cancel"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function SalesReturnPage() {
  const { t, language } = useTranslation();
  const formatDate = (dateStr) => dateStr ? new Date(dateStr).toLocaleDateString("en-GB") : "";
  const [returns, setReturns] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);

  const load = () => {
    setLoading(true);
    sales.returns().then(r => setReturns(r.data?.results ?? r.data ?? [])).catch(() => setReturns([])).finally(() => setLoading(false));
  };

  useEffect(load, []);

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold text-white">
            <RotateCcw className="h-6 w-6 text-orange-500" />{t("salesReturn")}
          </h1>
          <p className="mt-1 text-sm text-navy-500">
            {language === "ne" ? "उत्पादन फिर्ता र स्टक समायोजन" : "Product returns and automatic stock adjustment"}
          </p>
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition"
        >
          <Plus className="h-4 w-4" />{t("newReturn")}
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : returns.length === 0 ? (
        <div className="flex flex-col items-center rounded-2xl border border-navy-800 bg-navy-900 py-16 text-center">
          <RotateCcw className="h-10 w-10 text-navy-600 mb-3" />
          <h3 className="font-semibold text-white">{t("noData")}</h3>
          <p className="mt-1 text-sm text-navy-500">{language === "ne" ? "कुनै फिर्ता रेकर्ड छैन" : "No return records found"}</p>
          <button onClick={() => setShowModal(true)}
            className="mt-4 flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600 transition">
            <Plus className="h-4 w-4" /> {t("newReturn")}
          </button>
        </div>
      ) : (
        <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="border-b border-navy-800 px-5 py-3.5">
            <p className="text-sm font-semibold text-white">{returns.length} {language === "ne" ? "फिर्ता" : "returns"}</p>
          </div>
          <div className="divide-y divide-navy-800">
            {returns.map(r => (
              <div key={r.id} className="flex items-center gap-4 px-5 py-4 hover:bg-navy-800/40 transition">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-orange-100">
                  <RotateCcw className="h-4 w-4 text-orange-600" />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="font-semibold text-white text-sm">{t("originalInvoice")}: {r.invoice_number || r.original_sale}</p>
                  <p className="text-xs text-navy-500 mt-0.5">{formatDate(r.return_date)} · {r.reason || (language === "ne" ? "कारण उल्लेख छैन" : "No reason")}</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="font-bold text-red-500">- Rs. {parseFloat(r.amount || 0).toLocaleString("en-IN", { minimumFractionDigits: 2 })}</p>
                  <p className="text-xs text-green-500 mt-0.5">{t("stockAdjusted")}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {showModal && (
        <ReturnModal onClose={() => setShowModal(false)} onSaved={() => { setShowModal(false); load(); }} />
      )}
    </div>
  );
}
