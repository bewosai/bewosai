import { useState, useEffect } from "react";
import { useRef } from "react";
import {
  Plus, Search, Edit2, Trash2, X, AlertCircle, ShoppingCart, Upload, Image, Eye, Printer,
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

/* ─── Print Modal ─── */
function PrintModal({ purchase, onClose }) {
  const { currentBusiness } = useAuth();
  const [docType, setDocType] = useState("invoice"); // 'invoice' | 'proforma'
  const isProforma = docType === "proforma";
  const businessName = localStorage.getItem("business_name") || "Business Name";
  const businessAddress = localStorage.getItem("business_address") || "";
  const businessPhone = localStorage.getItem("business_phone") || "";
  const businessLogo = localStorage.getItem("business_logo") || null;
  const businessPan = currentBusiness?.pan_number || "";
  const footerText = localStorage.getItem("invoice_footer_text") || "Thank you for your business!";
  const items = purchase.items || [];

  const total = parseFloat(purchase.total || 0);
  const paid = parseFloat(purchase.paid_amount || 0);
  const due = total - paid;
  const paymentModeLabel = paid <= 0 && due > 0
    ? "Credit"
    : (PAYMENT_METHODS.find(m => m.value === purchase.payment_method)?.label || purchase.payment_method || "Cash");
  const billDate = purchase.purchase_date || purchase.date;
  const miti = billDate ? formatBS(adToBS(new Date(billDate))) : "";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-2xl rounded-2xl bg-white text-gray-800 shadow-2xl print:shadow-none print:rounded-none">
        <div className="flex items-center justify-between border-b p-4 print:hidden">
          <span className="font-bold text-gray-900">Print Bill</span>
          <div className="flex items-center gap-3">
            <label className="flex items-center gap-2 text-xs font-semibold text-gray-600">
              <input type="checkbox" checked={isProforma} onChange={e => setDocType(e.target.checked ? "proforma" : "invoice")} />
              Proforma
            </label>
            <button onClick={() => window.print()} className="rounded-lg bg-orange-500 px-4 py-2 text-sm text-white hover:bg-orange-600">
              <Printer size={14} className="mr-1 inline" /> Print
            </button>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-700"><X size={20} /></button>
          </div>
        </div>

        <div className="p-6 print:p-2 text-gray-800" id="print-area">
          {/* Business header */}
          <div className="mb-4 flex items-start justify-between gap-3">
            <div>
              <h2 className="text-xl font-bold text-gray-900">{businessName}</h2>
              <p className="text-xs text-gray-600">
                {businessPhone}{businessPhone && businessAddress ? "• " : ""}{businessAddress}
              </p>
              {businessPan && <p className="text-xs text-gray-600">PAN No: {businessPan}</p>}
            </div>
            {businessLogo && <img src={businessLogo} alt="logo" className="h-12 w-12 rounded-lg object-cover border" />}
          </div>

          <h3 className="mb-4 text-center text-lg font-bold uppercase tracking-wide text-gray-900">
            {isProforma ? "Proforma Invoice" : "Purchase Details"}
          </h3>

          {/* Supplier + bill meta */}
          <div className="mb-4 grid grid-cols-2 gap-4 text-sm">
            <div>
              <p className="text-gray-500">Supplier:</p>
              <p className="font-semibold text-gray-900">{purchase.supplier_name || purchase.party_name || "Unknown Supplier"}</p>
              {purchase.supplier_address && <p className="text-xs text-gray-500">{purchase.supplier_address}</p>}
              {purchase.supplier_pan && <p className="mt-1 text-xs text-gray-600">PAN No: {purchase.supplier_pan}</p>}
            </div>
            <div className="text-right text-xs">
              <p className="text-gray-500">Bill No: <span className="font-semibold text-gray-900">{purchase.bill_number || purchase.invoice_number || purchase.id}</span></p>
              <p className="text-gray-500">Bill Date: <span className="font-semibold text-gray-900">{billDate}</span></p>
              {miti && <p className="text-gray-500">Miti: <span className="font-semibold text-gray-900">{miti}</span></p>}
              <p className="text-gray-500">Payment Mode: <span className="font-semibold text-gray-900">{paymentModeLabel}</span></p>
            </div>
          </div>

          <table className="w-full text-sm border-collapse mb-4">
            <thead>
              <tr className="bg-blue-500 text-white">
                <th className="py-2 text-left pl-2 rounded-l-md">S.N.</th>
                <th className="py-2 text-left">Name</th>
                <th className="py-2 text-right">Quantity</th>
                <th className="py-2 text-right">Rate</th>
                <th className="py-2 text-right pr-2 rounded-r-md">Amount</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item, i) => {
                const rowTotal = (item.quantity * item.unit_price) - (item.discount_amount || 0);
                return (
                  <tr key={i} className="border-b border-gray-200">
                    <td className="py-2 pl-2 text-gray-500">{i + 1}</td>
                    <td className="py-2">{item.product_name || item.name}</td>
                    <td className="py-2 text-right">{item.quantity}</td>
                    <td className="py-2 text-right">Rs. {parseFloat(item.unit_price).toFixed(2)}</td>
                    <td className="py-2 text-right pr-2">Rs. {rowTotal.toFixed(2)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>

          {/* Amount in words + totals */}
          <div className="mb-2 grid grid-cols-2 gap-6">
            <div className="text-sm">
              <p className="font-semibold text-gray-700">Amount in Words</p>
              <p className="text-gray-600">{amountInWords(total)}</p>
              {isProforma && <p className="mt-2 text-xs italic text-gray-500">*Proforma Invoice</p>}
            </div>
            <div className="space-y-1 text-sm">
              <div className="flex justify-between"><span className="text-gray-500">Subtotal:</span><span>Rs. {parseFloat(purchase.subtotal || 0).toFixed(2)}</span></div>
              {parseFloat(purchase.discount || 0) > 0 && (
                <div className="flex justify-between text-red-500"><span>Discount:</span><span>- Rs. {parseFloat(purchase.discount).toFixed(2)}</span></div>
              )}
              {parseFloat(purchase.tax_amount || 0) > 0 && (
                <div className="flex justify-between"><span className="text-gray-500">Tax ({parseFloat(purchase.tax_rate || 0)}%):</span><span>+ Rs. {parseFloat(purchase.tax_amount).toFixed(2)}</span></div>
              )}
              <div className="flex justify-between font-semibold"><span className="text-gray-700">Total Amount:</span><span>Rs. {total.toFixed(2)}</span></div>
              <div className="flex justify-between"><span className="text-gray-500">Paid Amount:</span><span className="font-semibold">Rs. {paid.toFixed(2)}</span></div>
              <div className="flex justify-between border-t pt-1 text-base font-bold"><span>Amount Due</span><span>Rs. {due.toFixed(2)}</span></div>
            </div>
          </div>

          {purchase.notes && (
            <div className="mt-4 text-xs text-gray-500 border-t pt-2">Notes: {purchase.notes}</div>
          )}

          {/* Signature */}
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
  const taxRate = Math.min(100, Math.max(0, parseFloat(form.tax_rate) || 0));
  const taxAmount = taxableAmount * taxRate / 100;
  const grandTotal = taxableAmount + taxAmount;
  const balanceDue = Math.max(0, grandTotal - parseFloat(form.paid_amount || 0));

  // Same reasoning as Sales: a cash purchase is settled on the spot, so
  // Amount Paid defaults to the full total (kept in sync as items/discount/
  // tax change) instead of leaving a phantom payable behind. Stops once the
  // user actually edits Amount Paid themselves, and never touches an
  // existing purchase being edited.
  const [paidAmountTouched, setPaidAmountTouched] = useState(!!editData);
  useEffect(() => {
    if (paidAmountTouched || form.payment_method !== "CASH") return;
    setForm(f => ({ ...f, paid_amount: grandTotal }));
  }, [grandTotal, form.payment_method, paidAmountTouched]);

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
                  <label className="mb-1 block text-xs font-semibold text-navy-400">VAT / Tax (%)</label>
                  <input type="number" min="0" max="100" step="0.01"
                    className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
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
                <div className="col-span-6 sm:col-span-1 flex justify-end gap-1">
                  {item.bill_image_url && (
                    <button onClick={() => setViewBillImage(item.bill_image_url)} title="View Bill"
                      className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-blue-400">
                      <Image size={13} />
                    </button>
                  )}
                  <button onClick={() => setPrintItem(item)} title="Print"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Printer size={13} />
                  </button>
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
