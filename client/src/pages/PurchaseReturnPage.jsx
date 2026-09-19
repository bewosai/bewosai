import { useState, useEffect } from "react";
import { purchases } from "../api/index";
import { useTranslation } from "../utils/translations";
import { RotateCcw, Plus, Loader, X, AlertCircle } from "lucide-react";
import DatePicker from "../components/common/DatePicker";
import { todayStr, formatDateOnly } from "../utils/dates";

const today = () => todayStr();
const F = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500 transition";

function ReturnModal({ onClose, onSaved }) {
  const { language } = useTranslation();
  const bid = localStorage.getItem("business_id");
  const [form, setForm] = useState({ original_purchase: "", return_date: today(), reason: "", items: [] });
  const [bills, setBills] = useState([]);
  const [billSearch, setBillSearch] = useState("");
  const [showDrop, setShowDrop] = useState(false);
  const [loadingItems, setLoadingItems] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    purchases.list({ business: bid }).then(r => setBills(r.data.results ?? r.data)).catch(() => {});
  }, []);

  const filteredBills = bills.filter(b =>
    b.bill_number.toLowerCase().includes(billSearch.toLowerCase()) ||
    (b.supplier_name || "").toLowerCase().includes(billSearch.toLowerCase())
  );

  const pickBill = async (b) => {
    setForm(f => ({ ...f, original_purchase: b.id, items: [] }));
    setBillSearch(`${b.bill_number}${b.supplier_name ? ` — ${b.supplier_name}` : ""}`);
    setShowDrop(false);
    setLoadingItems(true);
    try {
      const { data } = await purchases.get(b.id);
      const items = (data.items || []).map(it => ({
        purchase_item: it.id,
        product: it.product ?? null,
        product_name: it.product_name,
        max_quantity: parseFloat(it.quantity),
        quantity: 0,
        unit_price: parseFloat(it.unit_price),
      }));
      setForm(f => ({ ...f, items }));
    } catch {
      setError("Failed to load bill items.");
    } finally {
      setLoadingItems(false);
    }
  };

  const setItemQty = (i, val) => {
    const items = [...form.items];
    const qty = Math.min(items[i].max_quantity, Math.max(0, parseFloat(val) || 0));
    items[i] = { ...items[i], quantity: qty };
    setForm(f => ({ ...f, items }));
  };

  const returnAmount = form.items.reduce((s, it) => s + it.quantity * it.unit_price, 0);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    if (!form.original_purchase) { setError("Select the original purchase bill."); return; }
    const returnedItems = form.items.filter(it => it.quantity > 0);
    if (returnedItems.length === 0) { setError("Enter a return quantity for at least one item."); return; }
    setSaving(true);
    try {
      await purchases.createReturn({
        original_purchase: form.original_purchase,
        return_date: form.return_date,
        reason: form.reason,
        amount: returnAmount.toFixed(2),
        items: returnedItems.map(it => ({
          purchase_item: it.purchase_item,
          product: it.product,
          product_name: it.product_name,
          quantity: it.quantity,
          unit_price: it.unit_price,
        })),
      });
      onSaved();
    } catch (e) {
      setError(e.response?.data?.detail || Object.values(e.response?.data || {})?.[0]?.[0] || "Failed to save.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-lg rounded-2xl border border-navy-700 bg-navy-900 p-6 shadow-2xl max-h-[90vh] overflow-y-auto">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{language === "ne" ? "नयाँ खरिद फिर्ता" : "New Purchase Return"}</h2>
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
              {language === "ne" ? "मूल बिल *" : "Original Bill *"}
            </label>
            <div className="relative">
              <input className={F} placeholder="Search by bill number or supplier…"
                value={billSearch}
                onChange={e => { setBillSearch(e.target.value); setShowDrop(true); setForm(f => ({ ...f, original_purchase: "" })); }}
                onFocus={() => setShowDrop(true)} onBlur={() => setTimeout(() => setShowDrop(false), 150)}
              />
              {showDrop && filteredBills.length > 0 && (
                <div className="absolute z-10 mt-1 w-full rounded-xl border border-navy-700 bg-navy-900 shadow-xl max-h-48 overflow-y-auto">
                  {filteredBills.slice(0, 20).map(b => (
                    <button key={b.id} type="button"
                      className="w-full px-3 py-2.5 text-left text-sm hover:bg-navy-800 flex items-center justify-between"
                      onMouseDown={() => pickBill(b)}
                    >
                      <span className="text-white">{b.bill_number}</span>
                      <span className="text-xs text-navy-400">{b.supplier_name || "—"} · Rs. {parseFloat(b.total).toLocaleString()}</span>
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
            <DatePicker value={form.return_date} onChange={(d) => setForm(f => ({ ...f, return_date: d }))} />
          </div>

          {loadingItems ? (
            <div className="flex justify-center py-4"><Loader className="h-5 w-5 animate-spin text-orange-500" /></div>
          ) : form.items.length > 0 && (
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">
                {language === "ne" ? "फिर्ता वस्तुहरू *" : "Items to Return *"}
              </label>
              <div className="rounded-xl border border-navy-700 overflow-hidden">
                <div className="grid grid-cols-12 gap-1 bg-navy-800/60 px-2 py-1.5 text-xs font-semibold text-navy-400">
                  <div className="col-span-5">Product</div>
                  <div className="col-span-3 text-right">Purchased</div>
                  <div className="col-span-4 text-right">Return Qty</div>
                </div>
                {form.items.map((item, i) => (
                  <div key={item.purchase_item ?? i} className="grid grid-cols-12 gap-1 px-2 py-2 border-t border-navy-700/50 items-center">
                    <div className="col-span-5 text-xs text-white truncate">{item.product_name}</div>
                    <div className="col-span-3 text-right text-xs text-navy-400">{item.max_quantity}</div>
                    <div className="col-span-4">
                      <input type="number" min="0" max={item.max_quantity} step="0.01"
                        className="w-full rounded-md bg-navy-800 border border-navy-700 px-2 py-1.5 text-xs text-white text-right focus:border-orange-500 focus:outline-none"
                        value={item.quantity}
                        onChange={e => setItemQty(i, e.target.value)}
                      />
                    </div>
                  </div>
                ))}
              </div>
              <div className="mt-2 flex justify-between text-sm">
                <span className="text-navy-400">{language === "ne" ? "फिर्ता रकम" : "Return Amount"}</span>
                <span className="font-bold text-white">Rs. {returnAmount.toFixed(2)}</span>
              </div>
            </div>
          )}

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

export default function PurchaseReturnPage() {
  const { t, language } = useTranslation();
  const formatDate = (dateStr) => formatDateOnly(dateStr);
  const [returns, setReturns] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);

  const load = () => {
    setLoading(true);
    purchases.returns().then(r => setReturns(r.data?.results ?? r.data ?? [])).catch(() => setReturns([])).finally(() => setLoading(false));
  };

  useEffect(load, []);

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold text-white">
            <RotateCcw className="h-6 w-6 text-orange-500" />{t("purchaseReturn")}
          </h1>
          <p className="mt-1 text-sm text-navy-500">
            {language === "ne" ? "उत्पादन फिर्ता र स्वचालित स्टक समायोजन" : "Product returns to suppliers and automatic stock adjustment"}
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
                  <p className="font-semibold text-white text-sm">
                    {language === "ne" ? "मूल बिल" : "Original Bill"}: {r.original_purchase_number || r.original_purchase}
                  </p>
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
