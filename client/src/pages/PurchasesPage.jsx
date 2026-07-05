import { useState, useEffect } from "react";
import { useRef } from "react";
import {
  Plus, Search, Edit2, Trash2, X, AlertCircle, ShoppingCart, Upload, Image, Eye,
} from "lucide-react";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import { purchases as purchasesApi, parties, inventory } from "../api/index.js";
import { adToBS, formatBS } from "../utils/nepaliDate";

const today = () => new Date().toISOString().slice(0, 10);

function formatDate(dateStr, dateMode, language) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  if (dateMode === "BS") {
    const bs = adToBS(d);
    return formatBS(bs, language);
  }
  return d.toLocaleDateString("en-GB");
}

const PAYMENT_METHODS = ["Cash", "Bank Transfer", "Credit", "Cheque", "Mobile Banking"];
const STATUS_COLORS = {
  CONFIRMED: "bg-green-500/10 text-green-400",
  DRAFT: "bg-navy-700/50 text-navy-400",
  PARTIAL: "bg-orange-500/10 text-orange-400",
  PAID: "bg-green-500/10 text-green-400",
  CANCELLED: "bg-red-500/10 text-red-400",
};

const EMPTY_ITEM = { product_id: "", product_name: "", quantity: 1, unit_price: 0, discount_amount: 0 };
const EMPTY_FORM = {
  supplier_id: "",
  supplier_name: "",
  bill_number: "",
  purchase_date: today(),
  due_date: "",
  items: [{ ...EMPTY_ITEM }],
  discount: 0,
  paid_amount: 0,
  payment_method: "Cash",
  notes: "",
  status: "CONFIRMED",
};

/* ─── Purchase Modal ─── */
function PurchaseModal({ onClose, onSaved, editData }) {
  const [form, setForm] = useState(editData ? {
    supplier_id: editData.supplier_id || "",
    supplier_name: editData.supplier_name || editData.party_name || "",
    bill_number: editData.bill_number || editData.invoice_number || "",
    purchase_date: editData.purchase_date || editData.date || today(),
    due_date: editData.due_date || "",
    items: editData.items?.length ? editData.items : [{ ...EMPTY_ITEM }],
    discount: editData.discount || 0,
    paid_amount: editData.paid_amount || 0,
    payment_method: editData.payment_method || "Cash",
    notes: editData.notes || "",
    status: editData.status || "CONFIRMED",
  } : { ...EMPTY_FORM, items: [{ ...EMPTY_ITEM }] });

  const [suppliers, setSuppliers] = useState([]);
  const [products, setProducts] = useState([]);
  const [supplierSearch, setSupplierSearch] = useState(form.supplier_name);
  const [showSupplierDropdown, setShowSupplierDropdown] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [billImage, setBillImage] = useState(null);   // File object
  const [billPreview, setBillPreview] = useState(editData?.bill_image_url || null);
  const [viewingImage, setViewingImage] = useState(false);
  const billImageRef = useRef(null);

  useEffect(() => {
    parties.list({ party_type: "SUPPLIER" }).then(r => setSuppliers(r.data.results ?? r.data)).catch(() => {});
    inventory.products().then(r => setProducts(r.data.results ?? r.data)).catch(() => {});
  }, []);

  const setItem = (i, key, val) => {
    const items = [...form.items];
    items[i] = { ...items[i], [key]: val };
    if (key === "product_id") {
      const prod = products.find(p => String(p.id) === String(val));
      if (prod) {
        items[i].product_name = prod.name;
        items[i].unit_price = parseFloat(prod.cost_price || prod.price || 0);
      }
    }
    setForm(f => ({ ...f, items }));
  };

  const addItem = () => setForm(f => ({ ...f, items: [...f.items, { ...EMPTY_ITEM }] }));
  const removeItem = (i) => setForm(f => ({ ...f, items: f.items.filter((_, idx) => idx !== i) }));

  const subtotal = form.items.reduce((s, it) => s + (it.quantity * it.unit_price) - (parseFloat(it.discount_amount) || 0), 0);
  const grandTotal = Math.max(0, subtotal - parseFloat(form.discount || 0));
  const balanceDue = Math.max(0, grandTotal - parseFloat(form.paid_amount || 0));

  const handleSubmit = async (statusOverride) => {
    setError("");
    if (!form.supplier_id && !form.supplier_name) { setError("Please select a supplier."); return; }
    setSaving(true);
    try {
      let payload;
      const baseData = {
        ...form,
        status: statusOverride || form.status,
        subtotal: subtotal.toFixed(2),
        total_amount: grandTotal.toFixed(2),
        due_amount: balanceDue.toFixed(2),
        items: JSON.stringify(form.items),
      };
      if (billImage) {
        payload = new FormData();
        Object.entries(baseData).forEach(([k, v]) => payload.append(k, v));
        payload.append("bill_image", billImage);
      } else {
        payload = { ...baseData, items: form.items };
      }
      if (editData?.id) {
        await purchasesApi.update(editData.id, payload);
      } else {
        await purchasesApi.create(payload);
      }
      onSaved();
    } catch (e) {
      setError(e.response?.data?.detail || "Failed to save. Check backend is running.");
    } finally {
      setSaving(false);
    }
  };

  const filteredSuppliers = suppliers.filter(s =>
    s.name?.toLowerCase().includes(supplierSearch?.toLowerCase() || "")
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-2 sm:p-4">
      <div className="w-full max-w-3xl max-h-[95vh] flex flex-col rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl">
        <div className="flex items-center justify-between border-b border-navy-800 p-5 shrink-0">
          <h2 className="text-lg font-bold text-white">{editData ? "Edit Purchase" : "New Purchase"}</h2>
          <button onClick={onClose} className="text-navy-500 hover:text-white"><X size={20} /></button>
        </div>

        <div className="flex-1 overflow-y-auto p-5 space-y-4">
          {error && (
            <div className="flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-sm text-red-400">
              <AlertCircle size={16} /> {error}
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="relative">
              <label className="mb-1 block text-xs font-semibold text-navy-400">Supplier *</label>
              <input
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                placeholder="Search supplier..."
                value={supplierSearch}
                onChange={e => { setSupplierSearch(e.target.value); setShowSupplierDropdown(true); }}
                onFocus={() => setShowSupplierDropdown(true)}
              />
              {showSupplierDropdown && filteredSuppliers.length > 0 && (
                <div className="absolute z-10 mt-1 w-full rounded-lg border border-navy-700 bg-navy-800 shadow-lg max-h-48 overflow-y-auto">
                  {filteredSuppliers.slice(0, 20).map(s => (
                    <button key={s.id} className="w-full px-3 py-2 text-left text-sm text-white hover:bg-navy-700"
                      onMouseDown={() => {
                        setForm(f => ({ ...f, supplier_id: s.id, supplier_name: s.name }));
                        setSupplierSearch(s.name);
                        setShowSupplierDropdown(false);
                      }}>
                      {s.name} {s.phone && <span className="text-navy-500 text-xs">· {s.phone}</span>}
                    </button>
                  ))}
                </div>
              )}
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Bill Number</label>
              <input
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                value={form.bill_number}
                onChange={e => setForm(f => ({ ...f, bill_number: e.target.value }))}
                placeholder="BILL-001"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Purchase Date *</label>
              <input type="date"
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
                value={form.purchase_date}
                onChange={e => setForm(f => ({ ...f, purchase_date: e.target.value }))}
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Due Date</label>
              <input type="date"
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
                value={form.due_date}
                onChange={e => setForm(f => ({ ...f, due_date: e.target.value }))}
              />
            </div>
          </div>

          {/* Items */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="text-xs font-semibold text-navy-400">Items</label>
              <button onClick={addItem} className="flex items-center gap-1 text-xs text-orange-400 hover:text-orange-300">
                <Plus size={14} /> Add Item
              </button>
            </div>
            <div className="rounded-xl border border-navy-700 overflow-hidden">
              <div className="grid grid-cols-12 gap-1 bg-navy-800/60 px-2 py-1.5 text-xs font-semibold text-navy-400">
                <div className="col-span-4">Product</div>
                <div className="col-span-2 text-right">Qty</div>
                <div className="col-span-2 text-right">Cost</div>
                <div className="col-span-2 text-right">Disc.</div>
                <div className="col-span-1 text-right">Total</div>
                <div className="col-span-1"></div>
              </div>
              {form.items.map((item, i) => {
                const rowTotal = (item.quantity * item.unit_price) - (parseFloat(item.discount_amount) || 0);
                return (
                  <div key={i} className="grid grid-cols-12 gap-1 px-2 py-2 border-t border-navy-700/50 items-center">
                    <div className="col-span-4">
                      <select
                        className="w-full rounded-md bg-navy-800 border border-navy-700 px-2 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none"
                        value={item.product_id}
                        onChange={e => setItem(i, "product_id", e.target.value)}
                      >
                        <option value="">Select...</option>
                        {products.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                      </select>
                    </div>
                    <div className="col-span-2">
                      <input type="number" min="1"
                        className="w-full rounded-md bg-navy-800 border border-navy-700 px-2 py-1.5 text-xs text-white text-right focus:border-orange-500 focus:outline-none"
                        value={item.quantity}
                        onChange={e => setItem(i, "quantity", parseFloat(e.target.value) || 1)}
                      />
                    </div>
                    <div className="col-span-2">
                      <input type="number" min="0"
                        className="w-full rounded-md bg-navy-800 border border-navy-700 px-2 py-1.5 text-xs text-white text-right focus:border-orange-500 focus:outline-none"
                        value={item.unit_price}
                        onChange={e => setItem(i, "unit_price", parseFloat(e.target.value) || 0)}
                      />
                    </div>
                    <div className="col-span-2">
                      <input type="number" min="0"
                        className="w-full rounded-md bg-navy-800 border border-navy-700 px-2 py-1.5 text-xs text-white text-right focus:border-orange-500 focus:outline-none"
                        value={item.discount_amount}
                        onChange={e => setItem(i, "discount_amount", parseFloat(e.target.value) || 0)}
                      />
                    </div>
                    <div className="col-span-1 text-right text-xs text-white font-medium">{rowTotal.toFixed(0)}</div>
                    <div className="col-span-1 flex justify-end">
                      {form.items.length > 1 && (
                        <button onClick={() => removeItem(i)} className="text-navy-500 hover:text-red-400"><X size={14} /></button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="space-y-3">
              <div>
                <label className="mb-1 block text-xs font-semibold text-navy-400">Discount (Rs.)</label>
                <input type="number" min="0"
                  className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
                  value={form.discount}
                  onChange={e => setForm(f => ({ ...f, discount: parseFloat(e.target.value) || 0 }))}
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-semibold text-navy-400">Notes</label>
                <textarea rows={2}
                  className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none resize-none text-sm"
                  value={form.notes}
                  onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
                  placeholder="Additional notes..."
                />
              </div>

              {/* Bill Image Upload */}
              <div>
                <label className="mb-1 block text-xs font-semibold text-navy-400">Bill Image (optional)</label>
                <input ref={billImageRef} type="file" accept="image/*" className="hidden"
                  onChange={e => {
                    const f = e.target.files?.[0];
                    if (f) { setBillImage(f); setBillPreview(URL.createObjectURL(f)); }
                  }} />
                {billPreview ? (
                  <div className="flex items-center gap-2">
                    <img src={billPreview} alt="bill" className="h-16 w-16 rounded-lg object-cover border border-navy-700 cursor-pointer"
                      onClick={() => setViewingImage(true)} />
                    <div className="text-xs text-navy-400">
                      <button onClick={() => setViewingImage(true)} className="flex items-center gap-1 text-blue-400 hover:underline mb-1">
                        <Eye className="h-3 w-3" /> View
                      </button>
                      <button onClick={() => { setBillImage(null); setBillPreview(null); if (billImageRef.current) billImageRef.current.value = ""; }}
                        className="flex items-center gap-1 text-red-400 hover:underline">
                        <X className="h-3 w-3" /> Remove
                      </button>
                    </div>
                  </div>
                ) : (
                  <button type="button" onClick={() => billImageRef.current?.click()}
                    className="flex items-center gap-2 rounded-xl border border-dashed border-navy-700 px-4 py-3 text-sm text-navy-400 hover:border-orange-500/50 hover:text-orange-400 transition w-full">
                    <Upload className="h-4 w-4" /> Upload bill photo
                  </button>
                )}
              </div>
            </div>
            <div className="rounded-xl border border-navy-700 bg-navy-800/40 p-4 space-y-2 text-sm">
              <div className="flex justify-between text-navy-400"><span>Subtotal</span><span>Rs. {subtotal.toFixed(2)}</span></div>
              <div className="flex justify-between text-navy-400"><span>Discount</span><span>- Rs. {parseFloat(form.discount || 0).toFixed(2)}</span></div>
              <div className="flex justify-between font-bold text-white border-t border-navy-700 pt-2"><span>Grand Total</span><span>Rs. {grandTotal.toFixed(2)}</span></div>
              <div className="pt-1 space-y-2">
                <div>
                  <label className="text-xs text-navy-400 block mb-1">Amount Paid</label>
                  <input type="number" min="0"
                    className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none text-sm"
                    value={form.paid_amount}
                    onChange={e => setForm(f => ({ ...f, paid_amount: parseFloat(e.target.value) || 0 }))}
                  />
                </div>
                <div>
                  <label className="text-xs text-navy-400 block mb-1">Payment Method</label>
                  <select
                    className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none text-sm"
                    value={form.payment_method}
                    onChange={e => setForm(f => ({ ...f, payment_method: e.target.value }))}
                  >
                    {PAYMENT_METHODS.map(m => <option key={m}>{m}</option>)}
                  </select>
                </div>
                <div className="flex justify-between font-semibold text-orange-400 border-t border-navy-700 pt-2">
                  <span>Balance Due</span><span>Rs. {balanceDue.toFixed(2)}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="flex gap-3 justify-end border-t border-navy-800 p-5 shrink-0">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800">Cancel</button>
          <button disabled={saving} onClick={() => handleSubmit("DRAFT")}
            className="px-4 py-2 rounded-lg border border-navy-700 text-navy-300 hover:bg-navy-800 disabled:opacity-50">
            Save as Draft
          </button>
          <button disabled={saving} onClick={() => handleSubmit("CONFIRMED")}
            className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50">
            {saving ? "Saving…" : "Confirm Purchase"}
          </button>
        </div>
      </div>

      {/* Full-screen image viewer */}
      {viewingImage && billPreview && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/90 p-4" onClick={() => setViewingImage(false)}>
          <img src={billPreview} alt="bill" className="max-h-full max-w-full rounded-xl object-contain" />
          <button className="absolute top-4 right-4 rounded-full bg-white/10 p-2 text-white hover:bg-white/20" onClick={() => setViewingImage(false)}>
            <X className="h-5 w-5" />
          </button>
        </div>
      )}
    </div>
  );
}

/* ─── Main Page ─── */
export default function PurchasesPage() {
  const { t } = useTranslation();
  const { dateMode, language } = useAppSettings();
  const maskAmount = usePrivateAmount();

  const [list, setList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState("ALL");
  const [search, setSearch] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [editItem, setEditItem] = useState(null);
  const [deleteItem, setDeleteItem] = useState(null);
  const [viewBillImage, setViewBillImage] = useState(null);

  const load = () => {
    setLoading(true);
    purchasesApi.list()
      .then(r => setList(r.data.results ?? r.data))
      .catch(() => setList([]))
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  const thisMonth = new Date().toISOString().slice(0, 7);
  const monthPurchases = list.filter(p => (p.purchase_date || p.date || "").startsWith(thisMonth));
  const totalPurchases = monthPurchases.reduce((s, x) => s + parseFloat(x.total_amount || 0), 0);
  const totalPayable = list.reduce((s, x) => s + parseFloat(x.due_amount || 0), 0);

  const TABS = ["ALL", "DRAFT", "CONFIRMED"];

  const filtered = list.filter(p => {
    const matchTab = tab === "ALL" || p.status === tab;
    const q = search.toLowerCase();
    const matchSearch = !q ||
      (p.bill_number || p.invoice_number || "").toLowerCase().includes(q) ||
      (p.supplier_name || p.party_name || "").toLowerCase().includes(q);
    return matchTab && matchSearch;
  });

  return (
    <div>
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">{t("purchases")}</h1>
          <p className="text-sm text-navy-500">Manage supplier bills and stock purchases</p>
        </div>
        <button onClick={() => { setEditItem(null); setShowModal(true); }}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600">
          <Plus size={16} /> New Purchase
        </button>
      </div>

      {/* Stats */}
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-3">
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">This Month</p>
          <p className="text-2xl font-bold text-white mt-1">{maskAmount(totalPurchases, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">Payable</p>
          <p className="text-2xl font-bold text-orange-400 mt-1">{maskAmount(totalPayable, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">Total Bills</p>
          <p className="text-2xl font-bold text-white mt-1">{list.length}</p>
        </div>
      </div>

      {/* Tabs + Search */}
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex gap-1 rounded-xl bg-navy-900 border border-navy-800 p-1">
          {TABS.map(t2 => (
            <button key={t2} onClick={() => setTab(t2)}
              className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${tab === t2 ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}>
              {t2}
            </button>
          ))}
        </div>
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-navy-500" />
          <input
            className="w-full sm:w-56 rounded-lg bg-navy-800 border border-navy-700 pl-9 pr-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
            placeholder="Search purchases..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
      </div>

      {/* List */}
      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
        {loading ? (
          <div className="py-16 text-center text-sm text-navy-400">{t("loading")}</div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center gap-3 py-16 text-center">
            <ShoppingCart className="h-12 w-12 text-navy-700" />
            <p className="text-sm text-navy-400">No purchase bills found</p>
            <button onClick={() => { setEditItem(null); setShowModal(true); }}
              className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600">
              <Plus size={14} /> Create First Purchase
            </button>
          </div>
        ) : (
          <>
            <div className="hidden sm:grid grid-cols-12 gap-2 px-4 py-2.5 text-xs font-semibold text-navy-500 border-b border-navy-800">
              <div className="col-span-2">Bill #</div>
              <div className="col-span-3">Supplier</div>
              <div className="col-span-2">Date</div>
              <div className="col-span-1 text-right">Total</div>
              <div className="col-span-1 text-right">Paid</div>
              <div className="col-span-1 text-right">Due</div>
              <div className="col-span-1">Status</div>
              <div className="col-span-1 text-right">Actions</div>
            </div>
            {filtered.map(item => (
              <div key={item.id}
                className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/50 hover:bg-navy-800/30 transition text-sm">
                <div className="col-span-12 sm:col-span-2 font-semibold text-orange-400">
                  #{item.bill_number || item.invoice_number || item.id}
                </div>
                <div className="col-span-12 sm:col-span-3 text-white truncate">
                  {item.supplier_name || item.party_name || "Unknown Supplier"}
                </div>
                <div className="col-span-6 sm:col-span-2 text-navy-400 text-xs">
                  {formatDate(item.purchase_date || item.date, dateMode, language)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-white font-medium">
                  {maskAmount(parseFloat(item.total_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-green-400 text-xs">
                  {maskAmount(parseFloat(item.paid_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-orange-400 text-xs">
                  {maskAmount(parseFloat(item.due_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-6 sm:col-span-1">
                  <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-semibold ${STATUS_COLORS[item.status] || "bg-navy-700 text-navy-400"}`}>
                    {item.status || "DRAFT"}
                  </span>
                </div>
                <div className="col-span-6 sm:col-span-1 flex justify-end gap-1">
                  {item.bill_image_url && (
                    <button onClick={() => setViewBillImage(item.bill_image_url)} title="View Bill"
                      className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-blue-400">
                      <Image size={13} />
                    </button>
                  )}
                  <button onClick={() => { setEditItem(item); setShowModal(true); }} title="Edit"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Edit2 size={13} />
                  </button>
                  <button onClick={() => setDeleteItem(item)} title="Delete"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-red-400">
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>
            ))}
          </>
        )}
      </div>

      {showModal && (
        <PurchaseModal
          editData={editItem}
          onClose={() => { setShowModal(false); setEditItem(null); }}
          onSaved={() => { setShowModal(false); setEditItem(null); load(); }}
        />
      )}
      {deleteItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-sm rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl p-6 space-y-4">
            <p className="text-white text-sm">Delete purchase #{deleteItem.bill_number || deleteItem.id}? This cannot be undone.</p>
            <div className="flex gap-3 justify-end">
              <button onClick={() => setDeleteItem(null)} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm">Cancel</button>
              <button onClick={async () => {
                try { await purchasesApi.delete(deleteItem.id); load(); } catch {}
                setDeleteItem(null);
              }} className="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600 text-sm">Delete</button>
            </div>
          </div>
        </div>
      )}

      {/* Bill image viewer */}
      {viewBillImage && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4" onClick={() => setViewBillImage(null)}>
          <img src={viewBillImage} alt="Bill" className="max-h-full max-w-full rounded-xl object-contain" />
          <button className="absolute top-4 right-4 rounded-full bg-white/10 p-2 text-white hover:bg-white/20" onClick={() => setViewBillImage(null)}>
            <X className="h-5 w-5" />
          </button>
        </div>
      )}
    </div>
  );
}
