import { useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Plus, Search, Edit2, Trash2, Eye, Printer, Share2, X,
  ChevronDown, Check, AlertCircle, ShoppingCart, FileText, RotateCcw, Copy
} from "lucide-react";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import { useAuth } from "../context/AuthContext";
import { sales as salesApi, parties, inventory, banking as bankingApi } from "../api/index.js";
import { adToBS, formatBS } from "../utils/nepaliDate";
import { amountInWords } from "../utils/amountInWords";
import { useEscToClose } from "../hooks/useEscToClose";
import SearchableSelect from "../components/common/SearchableSelect";
import { getRecentIds, pushRecentId } from "../utils/recentItems";
import { priceForUnit } from "../utils/calculations";
import { paymentStatus, PAYMENT_STATUS_META } from "../utils/paymentStatus";

const today = () => new Date().toISOString().slice(0, 10);
// "2026-03-05T14:30:00Z" (API) <-> "2026-03-05T14:30" (datetime-local input)
// — both in the browser's local time, so a reminder set for "2pm" reads
// back as "2pm" instead of drifting by the UTC offset.
function toDatetimeLocal(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d)) return "";
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function formatDate(dateStr, dateMode, language) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  if (dateMode === "BS") {
    const bs = adToBS(d);
    return formatBS(bs, language);
  }
  return d.toLocaleDateString("en-GB");
}

import { PAYMENT_METHODS as PM_CONSTS, SALE_STATUS } from "../constants";

// Sale.payment_method only accepts these values on the backend (see
// backend/sales/models.py METHOD_CHOICES) — the other PM_CONSTS entries
// (IME_PAY, MOBILE, CHEQUE, CREDIT) would 400 if submitted here.
const SALE_PAYMENT_METHOD_VALUES = ["CASH", "BANK", "ESEWA", "KHALTI", "SPLIT"];
const STATUS_COLORS = Object.fromEntries(
  Object.entries(SALE_STATUS).map(([k, v]) => [k, v.cls])
);

const EMPTY_ITEM = { product_id: "", product_name: "", quantity: 1, unit_label: "", unit_price: 0, discount_amount: 0 };
const EMPTY_FORM = {
  customer_id: "",
  customer_name: "",
  invoice_number: "",
  sale_date: today(),
  due_date: "",
  items: [{ ...EMPTY_ITEM }],
  discount: 0,
  tax_rate: 0,
  paid_amount: 0,
  payment_method: "CASH",
  bank_account: "",
  cash_amount: 0,
  reminder_enabled: false,
  reminder_at: "",
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

/* ─── Print Modal — classic ruled Tax Invoice layout, so it reads the way
     a Nepali business already expects a printed bill to look. ─── */
function PrintModal({ sale, onClose }) {
  const { currentBusiness } = useAuth();
  const businessName = localStorage.getItem("business_name") || "Business Name";
  const businessAddress = localStorage.getItem("business_address") || "";
  const businessPhone = localStorage.getItem("business_phone") || "";
  const businessLogo = localStorage.getItem("business_logo") || null;
  const businessPan = currentBusiness?.pan_number || "";
  const businessVat = currentBusiness?.vat_number || "";
  const items = sale.items || [];

  const subtotal = parseFloat(sale.subtotal || sale.total_amount || 0);
  const discount = parseFloat(sale.discount || 0);
  const taxAmount = parseFloat(sale.tax_amount || 0);
  const taxRate = parseFloat(sale.tax_rate || 0);
  const total = parseFloat(sale.total ?? sale.total_amount ?? 0);
  const paid = parseFloat(sale.paid_amount || 0);
  const due = total - paid;
  const isAdvance = due < 0;
  // Mode of Payment (which channel) and Bill Type (paid now vs owed) are
  // separate facts — see the Cash/Credit toggle on the form itself.
  const paymentModeLabel = PM_CONSTS.find(m => m.value === sale.payment_method)?.label || sale.payment_method || "Cash";
  const billType = paid <= 0 && due > 0 ? "Credit" : "Cash";
  const invoiceDate = sale.sale_date || sale.date;
  const miti = invoiceDate ? formatBS(adToBS(new Date(invoiceDate))) : "";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-3xl max-h-[90vh] overflow-y-auto rounded-2xl bg-[#ffffff] shadow-2xl print:max-h-none print:overflow-visible print:shadow-none print:rounded-none">
        <div className="flex items-center justify-between border-b p-4 print:hidden">
          <span className="font-bold text-gray-900">Print Invoice</span>
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

          {/* Customer + invoice meta */}
          <div className="grid grid-cols-2 gap-3 border-b-2 border-gray-800 px-4 py-2">
            <div className="space-y-0.5">
              <PrintRow label="Customer Name" value={sale.customer_name || sale.party_name || "Walk-in"} bold />
              <PrintRow label="Pan / Vat No." value={sale.party_pan} />
              <PrintRow label="Customer Address" value={sale.party_address} />
              <PrintRow label="Customer Cnt No." value={sale.party_phone} />
            </div>
            <div className="space-y-0.5">
              <PrintRow label="Invoice No." value={sale.invoice_number || sale.id} bold align="right" />
              <PrintRow label="Date of Transaction" value={invoiceDate} align="right" />
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
                {/* A short row count still reads like a real invoice book —
                    a few ruled blank rows instead of the table just stopping. */}
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
              {sale.notes && <p><span className="font-semibold">Remarks :</span> {sale.notes}</p>}
              <p className={sale.notes ? "mt-2" : ""}>
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
                    <td className="px-3 py-1">Received Amount</td><td>:</td>
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
              <div className="mx-auto mb-1 w-32 border-t border-gray-500 pt-1">Prepaid By</div>
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

/* ─── Quick-add customer, without leaving the invoice ─── */
function QuickAddCustomerModal({ initialName, onClose, onCreated }) {
  const [name, setName] = useState(initialName || "");
  const [phone, setPhone] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e) => {
    e.preventDefault();
    if (!name.trim()) {
      setError("Customer name is required.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const { data } = await parties.create({
        name: name.trim(),
        party_type: "CUSTOMER",
        phone: phone.trim(),
        opening_balance: 0,
      });
      onCreated(data);
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.detail || "Could not create customer.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-60 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={submit} className="w-full max-w-sm rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-base font-bold text-white">Add New Customer</h3>
          <button type="button" onClick={onClose} className="text-navy-500 hover:text-white"><X size={18} /></button>
        </div>
        {error && (
          <div className="flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">
            <AlertCircle size={14} /> {error}
          </div>
        )}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Customer Name *</label>
          <input autoFocus value={name} onChange={e => setName(e.target.value)}
            className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
            placeholder="e.g. Ram Prasad" />
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
            {saving ? "Adding…" : "Add Customer"}
          </button>
        </div>
      </form>
    </div>
  );
}

/* ─── Sale Modal (New/Edit) ─── */
function SaleModal({ onClose, onSaved, editData }) {
  useEscToClose(onClose);
  const { language } = useAppSettings();
  const { currentBusiness } = useAuth();
  const [form, setForm] = useState(editData ? {
    customer_id: editData.customer_id || editData.customer || "",
    customer_name: editData.customer_name || editData.party_name || "",
    invoice_number: editData.invoice_number || "",
    sale_date: editData.sale_date || editData.date || today(),
    due_date: editData.due_date || "",
    items: editData.items?.length
      ? editData.items.map(it => ({
          ...it,
          product_id: it.product_id ?? it.product ?? "",
        }))
      : [{ ...EMPTY_ITEM }],
    discount: editData.subtotal && parseFloat(editData.subtotal) > 0
      ? Math.round((parseFloat(editData.discount || 0) / parseFloat(editData.subtotal)) * 10000) / 100
      : (editData.discount || 0),
    tax_rate: editData.tax_rate ?? currentBusiness?.default_tax_rate ?? 0,
    paid_amount: editData.paid_amount || 0,
    payment_method: editData.payment_method || "CASH",
    bank_account: editData.bank_account || "",
    cash_amount: editData.cash_amount || 0,
    reminder_enabled: !!editData.reminder_enabled,
    reminder_at: toDatetimeLocal(editData.reminder_at),
    notes: editData.notes || "",
    status: editData.status || "CONFIRMED",
  } : { ...EMPTY_FORM, items: [{ ...EMPTY_ITEM }], tax_rate: currentBusiness?.default_tax_rate ?? 0 });

  // Whether VAT applies to this sale at all — kept separate from tax_rate
  // itself so unchecking it (e.g. a VAT-exempt customer) doesn't lose
  // whatever % was typed; re-checking restores it instead of forcing a
  // retype. Defaults on when there's already a nonzero rate (editing an
  // existing sale, or the business has a default VAT %).
  const [vatEnabled, setVatEnabled] = useState(() => parseFloat(form.tax_rate || 0) > 0);
  const [customers, setCustomers] = useState([]);
  const [products, setProducts] = useState([]);
  const [bankAccounts, setBankAccounts] = useState([]);
  const [customerSearch, setCustomerSearch] = useState(form.customer_name);
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  // Row index waiting on a newly-created product, so the cashier never has
  // to leave the invoice to add one that isn't in stock yet.
  const [quickAddForRow, setQuickAddForRow] = useState(null);
  const [showQuickAddCustomer, setShowQuickAddCustomer] = useState(false);
  const [recentProductIds, setRecentProductIds] = useState(() => getRecentIds(currentBusiness?.id, "products"));

  useEffect(() => {
    parties.list({ party_type: "CUSTOMER", page_size: 1000 }).then(r => setCustomers(r.data.results ?? r.data)).catch(() => {});
    inventory.products({ page_size: 1000 }).then(r => setProducts(r.data.results ?? r.data)).catch(() => {});
    bankingApi.accounts({ page_size: 1000 }).then(r => setBankAccounts(r.data.results ?? r.data)).catch(() => {});
    if (!editData) {
      salesApi.nextNumber?.().then(r => setForm(f => ({ ...f, invoice_number: r.data.next_number || "" }))).catch(() => {});
    }
  }, []);

  const setItem = (i, key, val) => {
    const items = [...form.items];
    items[i] = { ...items[i], [key]: val };
    if (key === "product_id") {
      const prod = products.find(p => String(p.id) === String(val));
      if (prod) {
        items[i].product_name = prod.name;
        items[i].unit_label = prod.unit_detail?.name || "";
        items[i].unit_price = parseFloat(prod.selling_price || prod.price || 0);
      }
      setRecentProductIds(pushRecentId(currentBusiness?.id, "products", val));
    }
    if (key === "unit_label") {
      const prod = products.find(p => String(p.id) === String(items[i].product_id));
      if (prod) {
        items[i].unit_price = priceForUnit(prod.selling_price || prod.price, prod.unit_detail, val);
      }
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
        product_id: product.id,
        product_name: product.name,
        unit_label: product.unit_detail?.name || "",
        unit_price: parseFloat(product.selling_price || 0),
      };
      return { ...f, items };
    });
    setQuickAddForRow(null);
  };

  const handleCustomerCreated = (customer) => {
    setCustomers(prev => [...prev, customer]);
    setForm(f => ({ ...f, customer_id: customer.id, customer_name: customer.name }));
    setCustomerSearch(customer.name);
    setShowQuickAddCustomer(false);
  };

  const subtotal = form.items.reduce((s, it) => s + (it.quantity * it.unit_price) - (parseFloat(it.discount_amount) || 0), 0);
  const discountPercent = Math.min(100, Math.max(0, parseFloat(form.discount) || 0));
  const discountAmount = subtotal * discountPercent / 100;
  const taxableAmount = Math.max(0, subtotal - discountAmount);
  const taxRate = vatEnabled ? Math.min(100, Math.max(0, parseFloat(form.tax_rate) || 0)) : 0;
  const taxAmount = taxableAmount * taxRate / 100;
  const grandTotal = taxableAmount + taxAmount;
  const balanceDue = Math.max(0, grandTotal - parseFloat(form.paid_amount || 0));

  // Cash vs Credit is a separate, explicit choice from Payment Method —
  // paying by Bank in full right now is still "Cash" in this sense (paid
  // today), while "Credit" means nothing is collected yet regardless of
  // which method will eventually settle it. Defaulting Amount Paid off of
  // this (full total for Cash, zero for Credit) means the cashier doesn't
  // have to manually clear/retype it for every sale. Only applies until
  // they actually edit Amount Paid themselves, and never touches an
  // existing sale being edited — that keeps whatever was actually recorded.
  const [creditSale, setCreditSale] = useState(() => !!editData && parseFloat(editData.due_amount || 0) > 0);
  const [paidAmountTouched, setPaidAmountTouched] = useState(!!editData);
  useEffect(() => {
    if (paidAmountTouched) return;
    setForm(f => ({ ...f, paid_amount: creditSale ? 0 : grandTotal }));
  }, [grandTotal, creditSale, paidAmountTouched]);

  const handleSubmit = async (statusOverride) => {
    setError("");
    if (!form.customer_id && !form.customer_name) { setError("Please select a customer."); return; }
    if (form.items.some(it => !it.product_id || !it.quantity || it.quantity <= 0)) {
      setError("Please select a product and a valid quantity for every item.");
      return;
    }
    if (form.payment_method !== "CASH" && !form.bank_account) {
      setError("Select which account this payment should hit.");
      return;
    }
    setSaving(true);
    try {
      const payload = {
        customer: form.customer_id || null,
        invoice_number: form.invoice_number,
        sale_date: form.sale_date,
        due_date: form.due_date || null,
        discount: discountAmount.toFixed(2),
        tax_rate: taxRate.toFixed(2),
        paid_amount: form.paid_amount || 0,
        payment_method: form.payment_method,
        bank_account: form.payment_method === "CASH" ? null : form.bank_account,
        cash_amount: form.payment_method === "SPLIT" ? (form.cash_amount || 0) : 0,
        reminder_enabled: form.reminder_enabled,
        reminder_at: form.reminder_enabled && form.reminder_at ? form.reminder_at : null,
        notes: form.notes,
        status: statusOverride || form.status,
        items: form.items.map(it => ({
          product: it.product_id || null,
          product_name: it.product_name,
          quantity: it.quantity,
          unit_label: it.unit_label || "",
          unit_price: it.unit_price,
          discount_amount: it.discount_amount || 0,
        })),
      };
      const isNew = !editData?.id;
      const res = isNew
        ? await salesApi.create(payload)
        : await salesApi.update(editData.id, payload);
      onSaved(res.data, isNew);
    } catch (e) {
      const data = e.response?.data;
      const msg = data?.detail ||
        (data && typeof data === "object" ? Object.values(data).flat().join(" ") : null);
      setError(msg || "Failed to save. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  const filteredCustomers = customers.filter(c =>
    c.name?.toLowerCase().includes(customerSearch?.toLowerCase() || "")
  );

  return (
    <>
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-2 sm:p-4">
      <div className="w-full max-w-3xl max-h-[95vh] flex flex-col rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-navy-800 p-5 shrink-0">
          {/* editData?.id, not just editData — duplicateSale() prefills
              editData with a copy that has its id deleted so it saves as a
              new invoice; checking editData alone would still show "Edit
              Invoice" for what's actually a new one. */}
          <h2 className="text-lg font-bold text-white">{editData?.id ? "Edit Invoice" : "New Invoice"}</h2>
          <button onClick={onClose} className="text-navy-500 hover:text-white"><X size={20} /></button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-5 space-y-4">
          {error && (
            <div className="flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-sm text-red-400">
              <AlertCircle size={16} /> {error}
            </div>
          )}

          {/* Customer + Invoice # */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="relative">
              <label className="mb-1 block text-xs font-semibold text-navy-400">Customer *</label>
              <input
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                placeholder="Search customer..."
                value={customerSearch}
                onChange={e => { setCustomerSearch(e.target.value); setShowCustomerDropdown(true); }}
                onFocus={() => setShowCustomerDropdown(true)}
              />
              {showCustomerDropdown && (
                <div className="absolute z-10 mt-1 w-full rounded-lg border border-navy-700 bg-navy-800 shadow-lg max-h-48 overflow-y-auto">
                  <button className="flex w-full items-center gap-1.5 px-3 py-2 text-left text-sm font-semibold text-orange-400 hover:bg-navy-700"
                    onMouseDown={() => {
                      setShowCustomerDropdown(false);
                      setShowQuickAddCustomer(true);
                    }}>
                    <Plus size={14} /> Add New Customer{customerSearch ? ` "${customerSearch}"` : ""}
                  </button>
                  {filteredCustomers.slice(0, 20).map(c => (
                    <button key={c.id} className="w-full px-3 py-2 text-left text-sm text-white hover:bg-navy-700 border-t border-navy-700/50"
                      onMouseDown={() => {
                        setForm(f => ({ ...f, customer_id: c.id, customer_name: c.name }));
                        setCustomerSearch(c.name);
                        setShowCustomerDropdown(false);
                      }}>
                      {c.name} {c.phone && <span className="text-navy-500 text-xs">· {c.phone}</span>}
                    </button>
                  ))}
                </div>
              )}
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Invoice Number</label>
              <input
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                value={form.invoice_number}
                onChange={e => setForm(f => ({ ...f, invoice_number: e.target.value }))}
                placeholder="INV-001"
              />
            </div>
          </div>

          {/* Dates */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="mb-1 block text-xs font-semibold text-navy-400">Invoice Date *</label>
              <input type="date"
                className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none"
                value={form.sale_date}
                onChange={e => setForm(f => ({ ...f, sale_date: e.target.value }))}
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

          {/* Payment Reminder — mirrors the mobile app's "Set Reminder" on
              Quick POS, but the web can't fire a background notification
              like the phone app does, so it's surfaced instead as a due
              reminder banner on the Dashboard. */}
          <div>
            <label className="flex items-center gap-2 text-xs font-semibold text-navy-400 cursor-pointer select-none">
              <input type="checkbox" checked={form.reminder_enabled}
                onChange={e => {
                  const checked = e.target.checked;
                  setForm(f => ({
                    ...f,
                    reminder_enabled: checked,
                    reminder_at: checked && !f.reminder_at
                      ? toDatetimeLocal(new Date(`${f.due_date || f.sale_date}T09:00`))
                      : f.reminder_at,
                  }));
                }}
              />
              Set Reminder
            </label>
            {form.reminder_enabled && (
              <input type="datetime-local"
                className="mt-1.5 w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none text-sm"
                value={form.reminder_at}
                onChange={e => setForm(f => ({ ...f, reminder_at: e.target.value }))}
              />
            )}
          </div>

          {/* Items Table */}
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
                <div className="col-span-2">Unit</div>
                <div className="col-span-1 text-right">Qty</div>
                <div className="col-span-2 text-right">Price</div>
                <div className="col-span-1 text-right">Disc.</div>
                <div className="col-span-1 text-right">Total</div>
                <div className="col-span-1"></div>
              </div>
              {form.items.map((item, i) => {
                const rowTotal = (item.quantity * item.unit_price) - (parseFloat(item.discount_amount) || 0);
                const prod = products.find(p => String(p.id) === String(item.product_id));
                const unitDetail = prod?.unit_detail;
                const hasSecondaryUnit = !!(unitDetail?.secondary_unit && unitDetail?.conversion_factor);
                return (
                  <div key={i} className="grid grid-cols-12 gap-1 px-2 py-2 border-t border-navy-700/50 items-center">
                    <div className="col-span-1 text-center text-xs text-navy-500">{i + 1}</div>
                    <div className="col-span-3">
                      <SearchableSelect
                        options={products.map(p => ({
                          id: p.id,
                          label: p.name,
                          sublabel: `Rs. ${parseFloat(p.selling_price || p.price || 0).toFixed(2)}`,
                          code: p.barcode || "",
                        }))}
                        value={item.product_id}
                        onChange={(id) => setItem(i, "product_id", id)}
                        onAddNew={() => setQuickAddForRow(i)}
                        addNewLabel="Add New Product"
                        placeholder="Search product..."
                        recentIds={recentProductIds}
                      />
                    </div>
                    <div className="col-span-2">
                      {hasSecondaryUnit ? (
                        <select
                          className="w-full rounded-md bg-navy-800 border border-navy-700 px-1 py-1.5 text-[11px] text-white focus:border-orange-500 focus:outline-none"
                          value={item.unit_label || unitDetail.name}
                          onChange={e => setItem(i, "unit_label", e.target.value)}
                        >
                          <option value={unitDetail.name}>{unitDetail.name}</option>
                          <option value={unitDetail.secondary_unit}>{unitDetail.secondary_unit}</option>
                        </select>
                      ) : (
                        <span className="text-[11px] text-navy-500">{unitDetail?.name || "—"}</span>
                      )}
                    </div>
                    <div className="col-span-1">
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
                    <div className="col-span-1">
                      <input type="number" min="0"
                        className="w-full rounded-md bg-navy-800 border border-navy-700 px-2 py-1.5 text-xs text-white text-right focus:border-orange-500 focus:outline-none"
                        value={item.discount_amount}
                        onChange={e => setItem(i, "discount_amount", parseFloat(e.target.value) || 0)}
                      />
                    </div>
                    <div className="col-span-1 text-right text-xs text-white font-medium">
                      {rowTotal.toFixed(0)}
                    </div>
                    <div className="col-span-1 flex justify-end">
                      {form.items.length > 1 && (
                        <button onClick={() => removeItem(i)} className="text-navy-500 hover:text-red-400">
                          <X size={14} />
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Summary + Payment */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="mb-1 block text-xs font-semibold text-navy-400">Overall Discount (%)</label>
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
                      Nothing collected yet — set a Due Date above so this shows up as overdue if it isn't paid in time.
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
                    {PM_CONSTS.filter(m => SALE_PAYMENT_METHOD_VALUES.includes(m.value)).map(m => (
                      <option key={m.value} value={m.value}>{m.label}</option>
                    ))}
                  </select>
                </div>
                {/* Only for non-cash methods, so the sale actually shows up
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
                {form.payment_method === "SPLIT" && (
                  <div>
                    <label className="text-xs text-navy-400 block mb-1">Cash Amount</label>
                    <input type="number" min="0" max={form.paid_amount}
                      className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-white focus:border-orange-500 focus:outline-none text-sm"
                      value={form.cash_amount}
                      onChange={e => setForm(f => ({ ...f, cash_amount: Math.max(0, Math.min(parseFloat(e.target.value) || 0, f.paid_amount)) }))}
                    />
                    <p className="mt-1 text-[11px] text-navy-500">
                      Rest goes to the bank account above — Rs. {Math.max(0, (parseFloat(form.paid_amount) || 0) - (parseFloat(form.cash_amount) || 0)).toFixed(2)}
                    </p>
                  </div>
                )}
                <div className="flex justify-between font-semibold text-orange-400 border-t border-navy-700 pt-2">
                  <span>Balance Due</span><span>Rs. {balanceDue.toFixed(2)}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex gap-3 justify-end border-t border-navy-800 p-5 shrink-0">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800">Cancel</button>
          <button disabled={saving} onClick={() => handleSubmit("DRAFT")}
            className="px-4 py-2 rounded-lg border border-navy-700 text-navy-300 hover:bg-navy-800 disabled:opacity-50">
            Save as Draft
          </button>
          <button disabled={saving} onClick={() => handleSubmit("CONFIRMED")}
            className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50">
            {saving ? "Saving…" : "Confirm Invoice"}
          </button>
        </div>
      </div>
    </div>
    {quickAddForRow !== null && (
      <QuickAddProductModal
        onClose={() => setQuickAddForRow(null)}
        onCreated={handleProductCreated}
      />
    )}
    {showQuickAddCustomer && (
      <QuickAddCustomerModal
        initialName={customerSearch}
        onClose={() => setShowQuickAddCustomer(false)}
        onCreated={handleCustomerCreated}
      />
    )}
    </>
  );
}

/* ─── Quick-add product, without leaving the invoice ─── */
function QuickAddProductModal({ onClose, onCreated }) {
  const [name, setName] = useState("");
  const [salePrice, setSalePrice] = useState("");
  const [purchasePrice, setPurchasePrice] = useState("");
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
        sale_price: parseFloat(salePrice) || 0,
        purchase_price: parseFloat(purchasePrice) || 0,
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
            <label className="mb-1 block text-xs font-semibold text-navy-400">Sale Price</label>
            <input type="number" min="0" value={salePrice} onChange={e => setSalePrice(e.target.value)}
              className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none" />
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-navy-400">Purchase Price</label>
            <input type="number" min="0" value={purchasePrice} onChange={e => setPurchasePrice(e.target.value)}
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

/* ─── Post-save confirmation ─── */
function SavedModal({ sale, onPrint, onShare, onNew, onClose }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-sm rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl p-6 text-center space-y-5">
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-green-500/10">
          <Check size={28} className="text-green-400" />
        </div>
        <div>
          <h2 className="text-lg font-bold text-white">Invoice Saved</h2>
          <p className="mt-1 text-sm text-navy-400">
            #{sale.invoice_number || sale.id} · {sale.customer_name || sale.party_name || "Walk-in"} · Rs. {parseFloat(sale.total ?? sale.total_amount ?? 0).toLocaleString()}
          </p>
        </div>
        <div className="grid grid-cols-2 gap-2">
          <button onClick={onPrint}
            className="flex items-center justify-center gap-2 rounded-lg border border-navy-700 px-3 py-2.5 text-sm font-medium text-white hover:bg-navy-800">
            <Printer size={15} /> Print
          </button>
          <button onClick={onShare}
            className="flex items-center justify-center gap-2 rounded-lg border border-navy-700 px-3 py-2.5 text-sm font-medium text-white hover:bg-navy-800">
            <Share2 size={15} /> Share
          </button>
        </div>
        <button onClick={onNew}
          className="flex w-full items-center justify-center gap-2 rounded-lg bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600">
          <Plus size={15} /> New Invoice
        </button>
        <button onClick={onClose} className="text-xs text-navy-500 hover:text-white">
          Done, back to list
        </button>
      </div>
    </div>
  );
}

/* ─── Delete Confirm ─── */
function ConfirmDialog({ message, onConfirm, onCancel }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-sm rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl p-6 space-y-4">
        <p className="text-white text-sm">{message}</p>
        <div className="flex gap-3 justify-end">
          <button onClick={onCancel} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm">Cancel</button>
          <button onClick={onConfirm} className="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600 text-sm">Delete</button>
        </div>
      </div>
    </div>
  );
}

/* ─── Main Page ─── */
export default function SalesPage() {
  const { t } = useTranslation();
  const { dateMode, language } = useAppSettings();
  const maskAmount = usePrivateAmount();

  const [saleList, setSaleList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState("ALL");
  const [paymentFilter, setPaymentFilter] = useState("ALL");
  const [search, setSearch] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [editSale, setEditSale] = useState(null);
  const [printSale, setPrintSale] = useState(null);
  const [deleteSale, setDeleteSale] = useState(null);
  const [confirmSale, setConfirmSale] = useState(null);
  const [searchParams, setSearchParams] = useSearchParams();

  // Shift+Q (see useKeyboardShortcuts) lands here as ?action=new.
  useEffect(() => {
    if (searchParams.get("action") === "new") {
      setEditSale(null);
      setShowModal(true);
      setSearchParams((prev) => { prev.delete("action"); return prev; }, { replace: true });
    }
  }, [searchParams, setSearchParams]);

  const load = () => {
    setLoading(true);
    salesApi.list()
      .then(r => setSaleList(r.data.results ?? r.data))
      .catch(() => setSaleList([]))
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  const thisMonth = new Date().toISOString().slice(0, 7);
  const monthSales = saleList.filter(s => (s.sale_date || s.date || "").startsWith(thisMonth));
  const totalSales = monthSales.reduce((s, x) => s + parseFloat(x.total ?? x.total_amount ?? 0), 0);
  const totalReceivable = saleList.reduce((s, x) => s + parseFloat(x.due_amount || 0), 0);
  const isOverdue = (s) =>
    s.status === "CONFIRMED" && parseFloat(s.due_amount || 0) > 0 && s.due_date && s.due_date < today();
  const overdueCount = saleList.filter(isOverdue).length;

  const TABS = ["ALL", "DRAFT", "CONFIRMED", "OVERDUE"];
  const PAYMENT_FILTERS = ["ALL", "PAID", "PARTIAL", "UNPAID"];

  const filtered = saleList.filter(s => {
    const matchTab = tab === "ALL" || (tab === "OVERDUE" ? isOverdue(s) : s.status === tab);
    const matchPayment = paymentFilter === "ALL" || paymentStatus(s) === paymentFilter;
    const q = search.toLowerCase();
    const matchSearch = !q || (s.invoice_number || "").toLowerCase().includes(q) ||
      (s.customer_name || s.party_name || "").toLowerCase().includes(q);
    return matchTab && matchPayment && matchSearch;
  });

  const handleDelete = async () => {
    try {
      await salesApi.update(deleteSale.id, { status: "CANCELLED" });
      setSaleList(prev => prev.filter(s => s.id !== deleteSale.id));
    } catch {}
    setDeleteSale(null);
  };

  const duplicateSale = async (sale) => {
    try {
      // Load full sale details (with items)
      const { data } = await salesApi.get(sale.id);
      // Get a new invoice number
      const numRes = await salesApi.nextNumber?.();
      const newInvoice = {
        ...data,
        invoice_number: numRes?.data?.next_number || `COPY-${data.invoice_number}`,
        sale_date: new Date().toISOString().slice(0, 10),
        status: "DRAFT",
        paid_amount: 0,
      };
      delete newInvoice.id;
      setEditSale(newInvoice);
      setShowModal(true);
    } catch {
      // fallback: open blank modal pre-filled
      setEditSale({ ...sale, id: undefined, status: "DRAFT", paid_amount: 0 });
      setShowModal(true);
    }
  };

  const handleSaved = (sale, isNew) => {
    setShowModal(false);
    setEditSale(null);
    load();
    if (isNew) setConfirmSale(sale);
  };

  const shareWhatsApp = (sale) => {
    const msg = `Invoice #${sale.invoice_number || sale.id}\nCustomer: ${sale.customer_name || sale.party_name || "Walk-in"}\nDate: ${sale.sale_date || sale.date}\nTotal: Rs. ${parseFloat(sale.total ?? sale.total_amount ?? 0).toFixed(2)}\nPaid: Rs. ${parseFloat(sale.paid_amount || 0).toFixed(2)}\nDue: Rs. ${parseFloat(sale.due_amount || 0).toFixed(2)}\nStatus: ${sale.status}`;
    window.open(`https://wa.me/?text=${encodeURIComponent(msg)}`, "_blank");
  };

  return (
    <div>
      {/* Header */}
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">{t("sales")}</h1>
          <p className="text-sm text-navy-500">Manage invoices, payments and sales records</p>
        </div>
        <button onClick={() => { setEditSale(null); setShowModal(true); }}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600">
          <Plus size={16} /> New Invoice
        </button>
      </div>

      {/* Stats */}
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">This Month Sales</p>
          <p className="text-2xl font-bold text-white mt-1">{maskAmount(totalSales, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">Receivable</p>
          <p className="text-2xl font-bold text-orange-400 mt-1">{maskAmount(totalReceivable, v => `Rs. ${Math.round(v).toLocaleString()}`)}</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">Total Invoices</p>
          <p className="text-2xl font-bold text-white mt-1">{saleList.length}</p>
        </div>
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-sm text-navy-500">Overdue</p>
          <p className="text-2xl font-bold text-red-400 mt-1">{overdueCount}</p>
        </div>
      </div>

      {/* Search + Tabs */}
      <div className="mb-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex gap-1 rounded-xl bg-navy-900 border border-navy-800 p-1 flex-wrap">
          {TABS.map(t2 => (
            <button key={t2}
              onClick={() => setTab(t2)}
              className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${tab === t2 ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}>
              {t2}
            </button>
          ))}
        </div>
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-navy-500" />
          <input
            className="w-full sm:w-56 rounded-lg bg-navy-800 border border-navy-700 pl-9 pr-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
            placeholder="Search invoices..."
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

      {/* Invoice List */}
      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
        {loading ? (
          <div className="py-16 text-center text-sm text-navy-400">{t("loading")}</div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center gap-3 py-16 text-center">
            <ShoppingCart className="h-12 w-12 text-navy-700" />
            <p className="text-sm text-navy-400">No invoices found</p>
            <button onClick={() => { setEditSale(null); setShowModal(true); }}
              className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600">
              <Plus size={14} /> Create First Invoice
            </button>
          </div>
        ) : (
          <>
            {/* Table header */}
            <div className="hidden sm:grid grid-cols-12 gap-2 px-4 py-2.5 text-xs font-semibold text-navy-500 border-b border-navy-800 bg-navy-900/80">
              <div className="col-span-2">Invoice #</div>
              <div className="col-span-2">Customer</div>
              <div className="col-span-1">Date</div>
              <div className="col-span-1 text-right">Total</div>
              <div className="col-span-1 text-right">Paid</div>
              <div className="col-span-1 text-right">Due</div>
              <div className="col-span-1">Status</div>
              <div className="col-span-3 text-right">Actions</div>
            </div>
            {filtered.map(sale => (
              <div key={sale.id}
                onClick={() => { setEditSale(sale); setShowModal(true); }}
                className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/50 hover:bg-navy-800/30 transition text-sm cursor-pointer">
                <div className="col-span-12 sm:col-span-2 font-semibold text-orange-400">
                  #{sale.invoice_number || sale.id}
                </div>
                <div className="col-span-12 sm:col-span-2 text-white truncate">
                  {sale.customer_name || sale.party_name || "Walk-in"}
                </div>
                <div className="col-span-12 sm:col-span-1 text-navy-400 text-xs">
                  {formatDate(sale.sale_date || sale.date, dateMode, language)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-white font-medium">
                  {maskAmount(parseFloat(sale.total ?? sale.total_amount ?? 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-green-400 text-xs">
                  {maskAmount(parseFloat(sale.paid_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-orange-400 text-xs">
                  {maskAmount(parseFloat(sale.due_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-6 sm:col-span-1 flex flex-col items-start gap-1">
                  <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-semibold ${STATUS_COLORS[sale.status] || "bg-navy-700 text-navy-400"}`}>
                    {sale.status || "DRAFT"}
                  </span>
                  <span className={`inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold ${PAYMENT_STATUS_META[paymentStatus(sale)].color}`}>
                    {PAYMENT_STATUS_META[paymentStatus(sale)].label}
                  </span>
                </div>
                {/* stopPropagation on every action — without it, clicking
                    Delete (or any of these) would also bubble up and open
                    the row's edit modal at the same time. */}
                <div className="col-span-6 sm:col-span-3 flex justify-end gap-0.5">
                  <button onClick={(e) => { e.stopPropagation(); setEditSale(sale); setShowModal(true); }} title="Edit"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Edit2 size={13} />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); duplicateSale(sale); }} title="Duplicate Invoice"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-orange-400">
                    <Copy size={13} />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); setPrintSale(sale); }} title="Print"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Printer size={13} />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); shareWhatsApp(sale); }} title="Share WhatsApp"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-green-400">
                    <Share2 size={13} />
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); setDeleteSale(sale); }} title="Delete"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-red-400">
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>
            ))}
          </>
        )}
      </div>

      {/* Modals */}
      {showModal && (
        <SaleModal
          editData={editSale}
          onClose={() => { setShowModal(false); setEditSale(null); }}
          onSaved={handleSaved}
        />
      )}
      {printSale && <PrintModal sale={printSale} onClose={() => setPrintSale(null)} />}
      {confirmSale && (
        <SavedModal
          sale={confirmSale}
          onPrint={() => { setPrintSale(confirmSale); setConfirmSale(null); }}
          onShare={() => shareWhatsApp(confirmSale)}
          onNew={() => { setConfirmSale(null); setEditSale(null); setShowModal(true); }}
          onClose={() => setConfirmSale(null)}
        />
      )}
      {deleteSale && (
        <ConfirmDialog
          message={`Delete invoice #${deleteSale.invoice_number || deleteSale.id}? This action cannot be undone.`}
          onConfirm={handleDelete}
          onCancel={() => setDeleteSale(null)}
        />
      )}
    </div>
  );
}
