import { useState, useEffect } from "react";
import { useRef } from "react";
import {
  Plus, Search, Edit2, Trash2, X, AlertCircle, ShoppingCart, Upload, Image, Eye, Printer, Copy,
} from "lucide-react";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import { useAuth } from "../context/AuthContext";
import { purchases as purchasesApi, parties, inventory, banking as bankingApi } from "../api/index.js";
import { adToBS, formatBS } from "../utils/nepaliDate";
import { amountInWords } from "../utils/amountInWords";
import SearchableSelect from "../components/common/SearchableSelect";
import { getRecentIds, pushRecentId } from "../utils/recentItems";
import { paymentStatus, PAYMENT_STATUS_META } from "../utils/paymentStatus";

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

const PAYMENT_METHODS = [
  { value: "CASH", label: "Cash" },
  { value: "BANK", label: "Bank" },
  { value: "ESEWA", label: "eSewa" },
  { value: "KHALTI", label: "Khalti" },
];
const STATUS_COLORS = {
  CONFIRMED: "bg-green-500/10 text-green-400",
  DRAFT: "bg-navy-700/50 text-navy-400",
  PARTIAL: "bg-orange-500/10 text-orange-400",
  PAID: "bg-green-500/10 text-green-400",
  CANCELLED: "bg-red-500/10 text-red-400",
};

const EMPTY_ITEM = { product: "", product_name: "", quantity: 1, unit_price: 0, discount_amount: 0 };
const EMPTY_FORM = {
  supplier: "",
  supplier_name: "",
  bill_number: "",
  purchase_date: today(),
  due_date: "",
  items: [{ ...EMPTY_ITEM }],
  discount: 0,
  tax_rate: 0,
  paid_amount: 0,
  payment_method: "CASH",
  bank_account: "",
  notes: "",
  status: "CONFIRMED",
};

/* ─── Print field row: "Label : Value" ─── */
function PrintRow({ label, value, bold, align }) {
  if (!value) return null;
  return (
    <p className={`flex gap-2 ${align === "right" ? "justify-end" : ""}`}>
      <span className="text-gray-600">{label} :</span>
      <span className={bold ? "font-semibold text-gray-900" : "text-gray-800"}>{value}</span>
    </p>
  );
}

/* ─── Print Modal — same classic ruled Tax Invoice layout as Sales ─── */
function PrintModal({ purchase, onClose }) {
  const { currentBusiness } = useAuth();
  const businessName = localStorage.getItem("business_name") || "Business Name";
  const businessAddress = localStorage.getItem("business_address") || "";
  const businessPhone = localStorage.getItem("business_phone") || "";
  const businessLogo = localStorage.getItem("business_logo") || null;
  const businessPan = currentBusiness?.pan_number || "";
  const businessVat = currentBusiness?.vat_number || "";
  const items = purchase.items || [];

  const subtotal = parseFloat(purchase.subtotal || 0);
  const discount = parseFloat(purchase.discount || 0);
  const taxAmount = parseFloat(purchase.tax_amount || 0);
  const taxRate = parseFloat(purchase.tax_rate || 0);
  const total = parseFloat(purchase.total || 0);
  const paid = parseFloat(purchase.paid_amount || 0);
  const due = total - paid;
  const isAdvance = due < 0;
  const paymentModeLabel = PAYMENT_METHODS.find(m => m.value === purchase.payment_method)?.label || purchase.payment_method || "Cash";
  const billType = paid <= 0 && due > 0 ? "Credit" : "Cash";
  const billDate = purchase.purchase_date || purchase.date;
  const miti = billDate ? formatBS(adToBS(new Date(billDate))) : "";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-3xl max-h-[90vh] overflow-y-auto rounded-2xl bg-[#ffffff] shadow-2xl print:max-h-none print:overflow-visible print:shadow-none print:rounded-none">
        <div className="flex items-center justify-between border-b p-4 print:hidden">
          <span className="font-bold text-gray-900">Print Bill</span>
          <div className="flex items-center gap-3">
            <button onClick={() => window.print()} className="rounded-lg bg-orange-500 px-4 py-2 text-sm text-white hover:bg-orange-600">
              <Printer size={14} className="mr-1 inline" /> Print
            </button>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-700"><X size={20} /></button>
          </div>
        </div>

        {/* A printed bill must always be pure white paper regardless of the
            app's own theme — plain bg-white would resolve through this app's
            --color-white token, which the light theme remaps to deep navy.
            The bracket value bypasses that token entirely. */}
        <div className="m-4 print:m-0 border-2 border-gray-800 bg-[#ffffff] text-xs text-gray-900" id="print-area">
          {/* Business header */}
          <div className="flex items-center gap-4 border-b-2 border-gray-800 p-4">
            {businessLogo && <img src={businessLogo} alt="logo" className="h-16 w-16 shrink-0 object-contain" />}
            <div className="flex-1 text-center">
              <h1 className="text-xl font-bold underline">{businessName}</h1>
              {businessAddress && <p className="mt-0.5">{businessAddress}</p>}
              <div className="mt-0.5 flex flex-wrap items-center justify-center gap-x-3 font-semibold">
                {businessPhone && <span>Ph.No: {businessPhone}</span>}
                {businessPan && <span>PAN No.: {businessPan}</span>}
                {businessVat && <span>VAT No.: {businessVat}</span>}
              </div>
            </div>
            {businessLogo && <div className="w-16 shrink-0" />}
          </div>

          <h2 className="border-b-2 border-gray-800 py-1.5 text-center text-sm font-bold uppercase tracking-widest underline">
            Tax Invoice
          </h2>

          {/* Supplier + bill meta */}
          <div className="grid grid-cols-2 gap-3 border-b-2 border-gray-800 px-4 py-2">
            <div className="space-y-0.5">
              <PrintRow label="Supplier Name" value={purchase.supplier_name || purchase.party_name || "Unknown Supplier"} bold />
              <PrintRow label="Pan / Vat No." value={purchase.supplier_pan} />
              <PrintRow label="Supplier Address" value={purchase.supplier_address} />
              <PrintRow label="Supplier Cnt No." value={purchase.supplier_phone} />
            </div>
            <div className="space-y-0.5">
              <PrintRow label="Bill No." value={purchase.bill_number || purchase.invoice_number || purchase.id} bold align="right" />
              <PrintRow label="Date of Transaction" value={billDate} align="right" />
              <PrintRow label="Miti of Transaction" value={miti} align="right" />
            </div>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-2 border-b-2 border-gray-800 px-4 py-1.5">
            <span>Mode of Payment : <strong>{paymentModeLabel}</strong></span>
            <span>Bill Type : <strong>{billType}</strong></span>
          </div>

          {/* Items */}
          <div className="overflow-x-auto print:overflow-visible">
            <table className="w-full min-w-120 border-collapse">
              <thead>
                <tr className="border-b-2 border-gray-800 font-semibold">
                  <th className="w-10 border-r border-gray-400 px-2 py-1.5 text-left">SNo</th>
                  <th className="w-20 border-r border-gray-400 px-2 py-1.5 text-left">HSCode</th>
                  <th className="border-r border-gray-400 px-2 py-1.5 text-left">Particular</th>
                  <th className="w-16 border-r border-gray-400 px-2 py-1.5 text-right">Qty</th>
                  <th className="w-20 border-r border-gray-400 px-2 py-1.5 text-right">Rate</th>
                  <th className="w-16 border-r border-gray-400 px-2 py-1.5 text-right">P.Disc</th>
                  <th className="w-24 px-2 py-1.5 text-right">Amount</th>
                </tr>
              </thead>
              <tbody>
                {items.map((item, i) => {
                  const rowTotal = (item.quantity * item.unit_price) - (item.discount_amount || 0);
                  return (
                    <tr key={i} className="border-b border-gray-300">
                      <td className="border-r border-gray-300 px-2 py-1.5">{i + 1}</td>
                      <td className="border-r border-gray-300 px-2 py-1.5">{item.product_hs_code || ""}</td>
                      <td className="border-r border-gray-300 px-2 py-1.5 font-medium">{item.product_name || item.name}</td>
                      <td className="border-r border-gray-300 px-2 py-1.5 text-right">{item.quantity}</td>
                      <td className="border-r border-gray-300 px-2 py-1.5 text-right">{parseFloat(item.unit_price).toFixed(2)}</td>
                      <td className="border-r border-gray-300 px-2 py-1.5 text-right">{parseFloat(item.discount_amount || 0).toFixed(2)}</td>
                      <td className="px-2 py-1.5 text-right font-medium">{rowTotal.toFixed(2)}</td>
                    </tr>
                  );
                })}
                {Array.from({ length: Math.max(0, 3 - items.length) }).map((_, i) => (
                  <tr key={`blank-${i}`} className="border-b border-gray-300">
                    <td className="border-r border-gray-300 px-2 py-3">&nbsp;</td>
                    <td className="border-r border-gray-300 px-2 py-3"></td>
                    <td className="border-r border-gray-300 px-2 py-3"></td>
                    <td className="border-r border-gray-300 px-2 py-3"></td>
                    <td className="border-r border-gray-300 px-2 py-3"></td>
                    <td className="border-r border-gray-300 px-2 py-3"></td>
                    <td className="px-2 py-3"></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Remarks/words + totals box */}
          <div className="grid grid-cols-2 border-t-2 border-gray-800">
            <div className="border-r-2 border-gray-800 p-3">
              {purchase.notes && <p><span className="font-semibold">Remarks :</span> {purchase.notes}</p>}
              <p className={purchase.notes ? "mt-2" : ""}>
                <span className="font-semibold">In Words :</span> Rs. {amountInWords(total)}
              </p>
              <p className="mt-2 text-[10px] italic text-gray-500">*Proforma Invoice</p>
            </div>
            <table className="border-collapse">
              <tbody>
                <tr className="border-b border-gray-300">
                  <td className="px-3 py-1">Basic Amount</td><td>:</td>
                  <td className="px-3 py-1 text-right font-semibold">{subtotal.toFixed(2)}</td>
                </tr>
                <tr className="border-b border-gray-300">
                  <td className="px-3 py-1">Discount</td><td>:</td>
                  <td className="px-3 py-1 text-right">{discount.toFixed(2)}</td>
                </tr>
                <tr className="border-b border-gray-300">
                  <td className="px-3 py-1 font-semibold">Taxable value</td><td>:</td>
                  <td className="px-3 py-1 text-right font-semibold">{(subtotal - discount).toFixed(2)}</td>
                </tr>
                <tr className="border-b border-gray-300">
                  <td className="px-3 py-1">Vat {taxRate % 1 === 0 ? taxRate.toFixed(0) : taxRate} %</td><td>:</td>
                  <td className="px-3 py-1 text-right">{taxAmount.toFixed(2)}</td>
                </tr>
                <tr className="border-b border-gray-300">
                  <td className="px-3 py-1 font-bold">Net Amount</td><td>:</td>
                  <td className="px-3 py-1 text-right font-bold">{total.toFixed(2)}</td>
                </tr>
                {paid > 0 && (
                  <tr className="border-b border-gray-300">
                    <td className="px-3 py-1">Paid Amount</td><td>:</td>
                    <td className="px-3 py-1 text-right">{paid.toFixed(2)}</td>
                  </tr>
                )}
                <tr>
                  <td className="px-3 py-1.5 font-bold">{isAdvance ? "Advance (Overpaid)" : "Amount Due"}</td><td>:</td>
                  <td className="px-3 py-1.5 text-right font-bold">{Math.abs(due).toFixed(2)}</td>
                </tr>
              </tbody>
            </table>
          </div>

          {/* Signatures */}
          <div className="grid grid-cols-3 border-t-2 border-gray-800 px-6 py-8 text-center">
            <div>
              <div className="mx-auto mb-1 w-32 border-t border-gray-500 pt-1">Received By</div>
            </div>
            <div>
              <div className="mx-auto mb-1 w-32 border-t border-gray-500 pt-1">Paid By</div>
            </div>
            <div>
              <p className="mb-8 font-semibold">For : {businessName}</p>
            </div>
          </div>

          <div className="border-t border-gray-400 px-4 py-1 text-right text-[10px] text-gray-500">
            Print Date &amp; Time : {new Date().toLocaleDateString("en-GB")} {new Date().toLocaleTimeString()}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ─── Quick-add supplier, without leaving the bill ─── */
function QuickAddSupplierModal({ initialName, onClose, onCreated }) {
  const [name, setName] = useState(initialName || "");
  const [phone, setPhone] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e) => {
    e.preventDefault();
    if (!name.trim()) {
      setError("Supplier name is required.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const { data } = await parties.create({
        name: name.trim(),
        party_type: "SUPPLIER",
        phone: phone.trim(),
        opening_balance: 0,
      });
      onCreated(data);
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.detail || "Could not create supplier.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-60 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={submit} className="w-full max-w-sm rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-base font-bold text-white">Add New Supplier</h3>
          <button type="button" onClick={onClose} className="text-navy-500 hover:text-white"><X size={18} /></button>
        </div>
        {error && (
          <div className="flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">
            <AlertCircle size={14} /> {error}
          </div>
        )}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Supplier Name *</label>
          <input autoFocus value={name} onChange={e => setName(e.target.value)}
            className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
            placeholder="e.g. Shyam Suppliers" />
        </div>
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Phone (optional)</label>
          <input value={phone} onChange={e => setPhone(e.target.value)}
            className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
            placeholder="98XXXXXXXX" />
        </div>
        <div className="flex gap-3 justify-end pt-1">
          <button type="button" onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm">Cancel</button>
          <button type="submit" disabled={saving}
            className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50 text-sm font-semibold">
            {saving ? "Adding…" : "Add Supplier"}
          </button>
        </div>
      </form>
    </div>
  );
}

/* ─── Purchase Modal ─── */
function PurchaseModal({ onClose, onSaved, editData }) {
  const { currentBusiness } = useAuth();
  const [form, setForm] = useState(editData ? {
    supplier: editData.supplier || "",
    supplier_name: editData.supplier_name || editData.party_name || "",
    bill_number: editData.bill_number || editData.invoice_number || "",
    purchase_date: editData.purchase_date || editData.date || today(),
    due_date: editData.due_date || "",
    items: editData.items?.length
      ? editData.items.map(it => ({ ...it, product: it.product ?? it.product_id ?? "" }))
      : [{ ...EMPTY_ITEM }],
    discount: editData.subtotal && parseFloat(editData.subtotal) > 0
      ? Math.round((parseFloat(editData.discount || 0) / parseFloat(editData.subtotal)) * 10000) / 100
      : (editData.discount || 0),
    tax_rate: editData.tax_rate ?? currentBusiness?.default_tax_rate ?? 0,
    paid_amount: editData.paid_amount || 0,
    payment_method: editData.payment_method || "CASH",
    bank_account: editData.bank_account || "",
    notes: editData.notes || "",
    status: editData.status || "CONFIRMED",
  } : { ...EMPTY_FORM, items: [{ ...EMPTY_ITEM }], tax_rate: currentBusiness?.default_tax_rate ?? 0 });

  // See SalesPage's identical vatEnabled — kept separate from tax_rate so
  // toggling VAT off doesn't lose whatever % was typed.
  const [vatEnabled, setVatEnabled] = useState(() => parseFloat(form.tax_rate || 0) > 0);
  const [suppliers, setSuppliers] = useState([]);
  const [products, setProducts] = useState([]);
  const [bankAccounts, setBankAccounts] = useState([]);
  const [supplierSearch, setSupplierSearch] = useState(form.supplier_name);
  const [showSupplierDropdown, setShowSupplierDropdown] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [billImage, setBillImage] = useState(null);   // File object
  const [billPreview, setBillPreview] = useState(editData?.bill_image_url || null);
  const [viewingImage, setViewingImage] = useState(false);
  const billImageRef = useRef(null);
  // Row index waiting on a newly-created product, so the cashier never has
  // to leave the bill to add one that isn't in stock yet.
  const [quickAddForRow, setQuickAddForRow] = useState(null);
  const [showQuickAddSupplier, setShowQuickAddSupplier] = useState(false);
  const [recentProductIds, setRecentProductIds] = useState(() => getRecentIds(currentBusiness?.id, "products"));

  useEffect(() => {
    parties.list({ party_type: "SUPPLIER", page_size: 1000 }).then(r => setSuppliers(r.data.results ?? r.data)).catch(() => {});
    inventory.products({ page_size: 1000 }).then(r => setProducts(r.data.results ?? r.data)).catch(() => {});
    bankingApi.accounts({ page_size: 1000 }).then(r => setBankAccounts(r.data.results ?? r.data)).catch(() => {});
    if (!editData) {
      purchasesApi.nextNumber?.().then(r => setForm(f => ({ ...f, bill_number: r.data.next_number || "" }))).catch(() => {});
    }
  }, []);

  const setItem = (i, key, val) => {
    const items = [...form.items];
    items[i] = { ...items[i], [key]: val };
    if (key === "product") {
      const prod = products.find(p => String(p.id) === String(val));
      if (prod) {
        items[i].product_name = prod.name;
        items[i].unit_price = parseFloat(prod.purchase_price || 0);
      }
      setRecentProductIds(pushRecentId(currentBusiness?.id, "products", val));
    }
    setForm(f => ({ ...f, items }));
  };

  const addItem = () => setForm(f => ({ ...f, items: [...f.items, { ...EMPTY_ITEM }] }));
  const removeItem = (i) => setForm(f => ({ ...f, items: f.items.filter((_, idx) => idx !== i) }));

  // Fills setItem's own lookup-by-id path once the new product is in
  // `products` — a direct setForm here would race the setProducts update.
  const handleProductCreated = (product) => {
    setProducts(prev => [...prev, product]);
    setForm(f => {
      const items = [...f.items];
      items[quickAddForRow] = {
        ...items[quickAddForRow],
        product: product.id,
        product_name: product.name,
        unit_price: parseFloat(product.purchase_price || 0),
      };
      return { ...f, items };
    });
    setQuickAddForRow(null);
  };

  const handleSupplierCreated = (supplier) => {
    setSuppliers(prev => [...prev, supplier]);
    setForm(f => ({ ...f, supplier: supplier.id, supplier_name: supplier.name }));
    setSupplierSearch(supplier.name);
    setShowQuickAddSupplier(false);
  };

  const subtotal = form.items.reduce((s, it) => s + (it.quantity * it.unit_price) - (parseFloat(it.discount_amount) || 0), 0);
  const discountPercent = Math.min(100, Math.max(0, parseFloat(form.discount) || 0));
  const discountAmount = subtotal * discountPercent / 100;
  const taxableAmount = Math.max(0, subtotal - discountAmount);
  const taxRate = vatEnabled ? Math.min(100, Math.max(0, parseFloat(form.tax_rate) || 0)) : 0;
  const taxAmount = taxableAmount * taxRate / 100;
  const grandTotal = taxableAmount + taxAmount;
  const balanceDue = Math.max(0, grandTotal - parseFloat(form.paid_amount || 0));

  // Cash vs Credit is a separate, explicit choice from Payment Method — see
  // SalesPage's identical reasoning. Defaults Amount Paid to the full total
  // for Cash or zero for Credit, until the user edits it themselves; never
  // touches an existing purchase being edited.
  const [creditSale, setCreditSale] = useState(() => !!editData && parseFloat(editData.due_amount || 0) > 0);
  const [paidAmountTouched, setPaidAmountTouched] = useState(!!editData);
  useEffect(() => {
    if (paidAmountTouched) return;
    setForm(f => ({ ...f, paid_amount: creditSale ? 0 : grandTotal }));
  }, [grandTotal, creditSale, paidAmountTouched]);

  const handleSubmit = async (statusOverride) => {
    setError("");
    if (!form.supplier && !form.supplier_name) { setError("Please select a supplier."); return; }
    if (form.items.some(it => !it.product || !it.quantity || it.quantity <= 0)) {
      setError("Please select a product and a valid quantity for every item.");
      return;
    }
    if (form.payment_method !== "CASH" && !form.bank_account) {
      setError("Select which account this payment should hit.");
      return;
    }
    setSaving(true);
    try {
      let payload;
      const baseData = {
        ...form,
        due_date: form.due_date || null,
        status: statusOverride || form.status,
        bank_account: form.payment_method === "CASH" ? null : form.bank_account,
        discount: discountAmount.toFixed(2),
        tax_rate: taxRate.toFixed(2),
        subtotal: subtotal.toFixed(2),
        total: grandTotal.toFixed(2),
        due_amount: balanceDue.toFixed(2),
        items: JSON.stringify(form.items),
      };
      if (billImage) {
        payload = new FormData();
        Object.entries(baseData).forEach(([k, v]) => {
          if (v !== null && v !== undefined) payload.append(k, v);
        });
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
      const data = e.response?.data;
      const msg = data?.detail ||
        (data && typeof data === "object" ? Object.values(data).flat().join(" ") : null);
      setError(msg || "Failed to save. Check backend is running.");
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
          {/* editData?.id, not just editData — see SalesPage's identical
              fix; duplicatePurchase() prefills editData with an id-less
              copy that must still read as "New Purchase". */}
          <h2 className="text-lg font-bold text-white">{editData?.id ? "Edit Purchase" : "New Purchase"}</h2>
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
              {showSupplierDropdown && (
                <div className="absolute z-10 mt-1 w-full rounded-lg border border-navy-700 bg-navy-800 shadow-lg max-h-48 overflow-y-auto">
                  <button className="flex w-full items-center gap-1.5 px-3 py-2 text-left text-sm font-semibold text-orange-400 hover:bg-navy-700"
                    onMouseDown={() => {
                      setShowSupplierDropdown(false);
                      setShowQuickAddSupplier(true);
                    }}>
                    <Plus size={14} /> Add New Supplier{supplierSearch ? ` "${supplierSearch}"` : ""}
                  </button>
                  {filteredSuppliers.slice(0, 20).map(s => (
                    <button key={s.id} className="w-full px-3 py-2 text-left text-sm text-white hover:bg-navy-700 border-t border-navy-700/50"
                      onMouseDown={() => {
                        setForm(f => ({ ...f, supplier: s.id, supplier_name: s.name }));
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
                <div className="col-span-1 text-center">S.N.</div>
                <div className="col-span-3">Product</div>
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
                    <div className="col-span-1 text-center text-xs text-navy-500">{i + 1}</div>
                    <div className="col-span-3">
                      <SearchableSelect
                        options={products.map(p => ({
                          id: p.id,
                          label: p.name,
                          sublabel: `Rs. ${parseFloat(p.purchase_price || 0).toFixed(2)}`,
                          code: p.barcode || "",
                        }))}
                        value={item.product}
                        onChange={(id) => setItem(i, "product", id)}
                        onAddNew={() => setQuickAddForRow(i)}
                        addNewLabel="Add New Product"
                        placeholder="Search product..."
                        recentIds={recentProductIds}
                      />
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
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="mb-1 block text-xs font-semibold text-navy-400">Discount (%)</label>
                  <input type="number" min="0" max="100" step="0.01"
                    className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
                    value={form.discount}
                    onChange={e => setForm(f => ({ ...f, discount: parseFloat(e.target.value) || 0 }))}
                  />
                </div>
                <div>
                  <div className="mb-1 flex items-center justify-between">
                    <label className="block text-xs font-semibold text-navy-400">VAT / Tax (%)</label>
                    <label className="flex items-center gap-1.5 text-xs text-navy-400 cursor-pointer select-none">
                      <input type="checkbox" checked={vatEnabled} onChange={e => setVatEnabled(e.target.checked)} />
                      Apply VAT
                    </label>
                  </div>
                  <input type="number" min="0" max="100" step="0.01" disabled={!vatEnabled}
                    className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none disabled:opacity-40"
                    value={form.tax_rate}
                    onChange={e => setForm(f => ({ ...f, tax_rate: parseFloat(e.target.value) || 0 }))}
                  />
                </div>
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
              <div className="flex justify-between text-navy-400"><span>Discount ({discountPercent}%)</span><span>- Rs. {discountAmount.toFixed(2)}</span></div>
              <div className="flex justify-between text-navy-400"><span>Tax ({taxRate}%)</span><span>+ Rs. {taxAmount.toFixed(2)}</span></div>
              <div className="flex justify-between font-bold text-white border-t border-navy-700 pt-2"><span>Grand Total</span><span>Rs. {grandTotal.toFixed(2)}</span></div>
              <div className="pt-1 space-y-2">
                <div>
                  <label className="text-xs text-navy-400 block mb-1">Cash or Credit?</label>
                  <div className="flex rounded-lg border border-navy-700 overflow-hidden text-xs font-semibold">
                    <button type="button" onClick={() => { setCreditSale(false); setPaidAmountTouched(false); }}
                      className={`flex-1 py-2 transition ${!creditSale ? "bg-orange-500 text-white" : "bg-navy-800 text-navy-400 hover:text-white"}`}>
                      Cash
                    </button>
                    <button type="button" onClick={() => { setCreditSale(true); setPaidAmountTouched(false); }}
                      className={`flex-1 py-2 transition ${creditSale ? "bg-orange-500 text-white" : "bg-navy-800 text-navy-400 hover:text-white"}`}>
                      Credit
                    </button>
                  </div>
                  {creditSale && (
                    <p className="mt-1 text-[11px] text-amber-400">
                      Nothing paid yet — set a Due Date above so this shows up as overdue if it isn't settled in time.
                    </p>
                  )}
                </div>
                <div>
                  <label className="text-xs text-navy-400 block mb-1">Amount Paid</label>
                  <input type="number" min="0"
                    className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none text-sm"
                    value={form.paid_amount}
                    onChange={e => {
                      setPaidAmountTouched(true);
                      setForm(f => ({ ...f, paid_amount: parseFloat(e.target.value) || 0 }));
                    }}
                  />
                </div>
                <div>
                  <label className="text-xs text-navy-400 block mb-1">Payment Method</label>
                  <select
                    className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none text-sm"
                    value={form.payment_method}
                    onChange={e => setForm(f => ({ ...f, payment_method: e.target.value }))}
                  >
                    {PAYMENT_METHODS.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
                  </select>
                </div>
                {/* Only for non-cash methods, so the bill actually shows up
                    on that account's Bank Statement instead of
                    payment_method being purely cosmetic. */}
                {form.payment_method !== "CASH" && (
                  <div>
                    <label className="text-xs text-navy-400 block mb-1">Account *</label>
                    {bankAccounts.length === 0 ? (
                      <p className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-300">
                        No bank accounts yet — add one in Banking, or switch this to Cash.
                      </p>
                    ) : (
                      <select
                        className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none text-sm"
                        value={form.bank_account}
                        onChange={e => setForm(f => ({ ...f, bank_account: e.target.value }))}
                      >
                        <option value="">Select account…</option>
                        {bankAccounts.map(a => (
                          <option key={a.id} value={a.id}>{a.account_name}{a.bank_name ? ` (${a.bank_name})` : ""}</option>
                        ))}
                      </select>
                    )}
                  </div>
                )}
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

      {quickAddForRow !== null && (
        <QuickAddProductModal
          onClose={() => setQuickAddForRow(null)}
          onCreated={handleProductCreated}
        />
      )}
      {showQuickAddSupplier && (
        <QuickAddSupplierModal
          initialName={supplierSearch}
          onClose={() => setShowQuickAddSupplier(false)}
          onCreated={handleSupplierCreated}
        />
      )}
    </div>
  );
}

/* ─── Quick-add product, without leaving the bill ─── */
function QuickAddProductModal({ onClose, onCreated }) {
  const [name, setName] = useState("");
  const [purchasePrice, setPurchasePrice] = useState("");
  const [salePrice, setSalePrice] = useState("");
  const [stockQuantity, setStockQuantity] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e) => {
    e.preventDefault();
    if (!name.trim()) {
      setError("Product name is required.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const { data } = await inventory.createProduct({
        name: name.trim(),
        purchase_price: parseFloat(purchasePrice) || 0,
        sale_price: parseFloat(salePrice) || 0,
        stock_quantity: parseFloat(stockQuantity) || 0,
      });
      onCreated(data);
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.detail || "Could not create product.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-60 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={submit} className="w-full max-w-sm rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-base font-bold text-white">Add New Product</h3>
          <button type="button" onClick={onClose} className="text-navy-500 hover:text-white"><X size={18} /></button>
        </div>
        {error && (
          <div className="flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">
            <AlertCircle size={14} /> {error}
          </div>
        )}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Product Name *</label>
          <input autoFocus value={name} onChange={e => setName(e.target.value)}
            className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
            placeholder="e.g. Coca Cola 500ml" />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Purchase Price</label>
            <input type="number" min="0" value={purchasePrice} onChange={e => setPurchasePrice(e.target.value)}
              className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none" />
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Sale Price</label>
            <input type="number" min="0" value={salePrice} onChange={e => setSalePrice(e.target.value)}
              className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none" />
          </div>
        </div>
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Opening Stock</label>
          <input type="number" min="0" value={stockQuantity} onChange={e => setStockQuantity(e.target.value)}
            className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none" />
        </div>
        <div className="flex gap-3 justify-end pt-1">
          <button type="button" onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm">Cancel</button>
          <button type="submit" disabled={saving}
            className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50 text-sm font-semibold">
            {saving ? "Adding…" : "Add Product"}
          </button>
        </div>
      </form>
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
  const [paymentFilter, setPaymentFilter] = useState("ALL");
  const [search, setSearch] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [editItem, setEditItem] = useState(null);
  const [deleteItem, setDeleteItem] = useState(null);
  const [deleteError, setDeleteError] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [printItem, setPrintItem] = useState(null);
  const [viewBillImage, setViewBillImage] = useState(null);

  const load = () => {
    setLoading(true);
    purchasesApi.list()
      .then(r => setList(r.data.results ?? r.data))
      .catch(() => setList([]))
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  // The list response already includes each purchase's items (same
  // PurchaseSerializer as the detail endpoint), so no re-fetch is needed —
  // just prefill the form with a copy that has no id, so it saves as a new
  // purchase (see the modal title's editData?.id check).
  const duplicatePurchase = async (item) => {
    const numRes = await purchasesApi.nextNumber?.();
    const newPurchase = {
      ...item,
      bill_number: numRes?.data?.next_number || `COPY-${item.bill_number}`,
      purchase_date: new Date().toISOString().slice(0, 10),
      status: "DRAFT",
      paid_amount: 0,
    };
    delete newPurchase.id;
    setEditItem(newPurchase);
    setShowModal(true);
  };

  const thisMonth = new Date().toISOString().slice(0, 7);
  const monthPurchases = list.filter(p => (p.purchase_date || p.date || "").startsWith(thisMonth));
  const totalPurchases = monthPurchases.reduce((s, x) => s + parseFloat(x.total || 0), 0);
  const totalPayable = list.reduce((s, x) => s + parseFloat(x.due_amount || 0), 0);

  const TABS = ["ALL", "DRAFT", "CONFIRMED"];
  const PAYMENT_FILTERS = ["ALL", "PAID", "PARTIAL", "UNPAID"];

  const filtered = list.filter(p => {
    const matchTab = tab === "ALL" || p.status === tab;
    const matchPayment = paymentFilter === "ALL" || paymentStatus(p) === paymentFilter;
    const q = search.toLowerCase();
    const matchSearch = !q ||
      (p.bill_number || p.invoice_number || "").toLowerCase().includes(q) ||
      (p.supplier_name || p.party_name || "").toLowerCase().includes(q);
    return matchTab && matchPayment && matchSearch;
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
      <div className="mb-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
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

      {/* Payment status filter */}
      <div className="mb-4 flex gap-1 rounded-xl bg-navy-900 border border-navy-800 p-1 w-fit flex-wrap">
        {PAYMENT_FILTERS.map(pf => (
          <button key={pf}
            onClick={() => setPaymentFilter(pf)}
            className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${paymentFilter === pf ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}>
            {pf === "ALL" ? "All Payments" : PAYMENT_STATUS_META[pf].label}
          </button>
        ))}
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
              <div className="col-span-2">Supplier</div>
              <div className="col-span-1">Date</div>
              <div className="col-span-1 text-right">Total</div>
              <div className="col-span-1 text-right">Paid</div>
              <div className="col-span-1 text-right">Due</div>
              <div className="col-span-1">Status</div>
              <div className="col-span-3 text-right">Actions</div>
            </div>
            {filtered.map(item => (
              <div key={item.id}
                onClick={() => { setEditItem(item); setShowModal(true); }}
                className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/50 hover:bg-navy-800/30 transition text-sm cursor-pointer">
                <div className="col-span-12 sm:col-span-2 font-semibold text-orange-400">
                  #{item.bill_number || item.invoice_number || item.id}
                </div>
                <div className="col-span-12 sm:col-span-2 text-white truncate">
                  {item.supplier_name || item.party_name || "Unknown Supplier"}
                </div>
                <div className="col-span-6 sm:col-span-1 text-navy-400 text-xs">
                  {formatDate(item.purchase_date || item.date, dateMode, language)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-white font-medium">
                  {maskAmount(parseFloat(item.total || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-green-400 text-xs">
                  {maskAmount(parseFloat(item.paid_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-orange-400 text-xs">
                  {maskAmount(parseFloat(item.due_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-6 sm:col-span-1 flex flex-col items-start gap-1">
                  <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-semibold ${STATUS_COLORS[item.status] || "bg-navy-700 text-navy-400"}`}>
                    {item.status || "DRAFT"}
                  </span>
                  <span className={`inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold ${PAYMENT_STATUS_META[paymentStatus(item)].color}`}>
                    {PAYMENT_STATUS_META[paymentStatus(item)].label}
                  </span>
                </div>
                {/* stopPropagation on every action — without it, clicking
                    Delete (or any of these) would also bubble up and open
                    the row's edit modal at the same time. */}
                <div className="col-span-6 sm:col-span-3 flex justify-end gap-0.5">
                  {item.bill_image_url && (
                    <button onClick={(e) => { e.stopPropagation(); setViewBillImage(item.bill_image_url); }} title="View Bill"
                      className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-blue-400">
                      <Image size={13} />
                    </button>
                  )}
                  <button onClick={(e) => { e.stopPropagation(); setPrintItem(item); }} title="Print"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Printer size={13} />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); setEditItem(item); setShowModal(true); }} title="Edit"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Edit2 size={13} />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); duplicatePurchase(item); }} title="Duplicate Purchase"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-orange-400">
                    <Copy size={13} />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); setDeleteItem(item); }} title="Delete"
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
      {printItem && <PrintModal purchase={printItem} onClose={() => setPrintItem(null)} />}
      {deleteItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-sm rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl p-6 space-y-4">
            <p className="text-white text-sm">Delete purchase #{deleteItem.bill_number || deleteItem.id}? This cannot be undone.</p>
            {deleteError && <p className="rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">{deleteError}</p>}
            <div className="flex gap-3 justify-end">
              <button disabled={deleting} onClick={() => { setDeleteItem(null); setDeleteError(""); }} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm disabled:opacity-50">Cancel</button>
              <button disabled={deleting} onClick={async () => {
                setDeleting(true);
                setDeleteError("");
                try {
                  await purchasesApi.delete(deleteItem.id);
                  load();
                  setDeleteItem(null);
                } catch (e) {
                  setDeleteError(e.response?.data?.error || e.response?.data?.detail || "Couldn't delete this purchase. Please try again.");
                }
                setDeleting(false);
              }} className="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600 text-sm disabled:opacity-50">{deleting ? "Deleting…" : "Delete"}</button>
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
