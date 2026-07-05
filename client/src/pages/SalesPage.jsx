import { useState, useEffect } from "react";
import {
  Plus, Search, Edit2, Trash2, Eye, Printer, Share2, X,
  ChevronDown, Check, AlertCircle, ShoppingCart, FileText, RotateCcw, Copy
} from "lucide-react";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount, useAppSettings } from "../context/AppSettingsContext";
import { sales as salesApi, parties, inventory } from "../api/index.js";
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

import { PAYMENT_METHODS as PM_CONSTS, SALE_STATUS } from "../constants";

const PAYMENT_METHODS = PM_CONSTS.map(m => m.value);
const STATUS_COLORS = Object.fromEntries(
  Object.entries(SALE_STATUS).map(([k, v]) => [k, v.cls])
);

const EMPTY_ITEM = { product_id: "", product_name: "", quantity: 1, unit_price: 0, discount_amount: 0 };
const EMPTY_FORM = {
  customer_id: "",
  customer_name: "",
  invoice_number: "",
  sale_date: today(),
  due_date: "",
  items: [{ ...EMPTY_ITEM }],
  discount: 0,
  paid_amount: 0,
  payment_method: "Cash",
  notes: "",
  status: "CONFIRMED",
};

/* ─── Print Modal ─── */
function PrintModal({ sale, onClose }) {
  const businessName = localStorage.getItem("business_name") || "Business Name";
  const businessAddress = localStorage.getItem("business_address") || "";
  const businessPhone = localStorage.getItem("business_phone") || "";
  const businessLogo = localStorage.getItem("business_logo") || null;
  const headerColor = localStorage.getItem("invoice_header_color") || "#f97316";
  const footerText = localStorage.getItem("invoice_footer_text") || "Thank you for your business!";
  const invoicePrefix = localStorage.getItem("invoice_prefix") || "";
  const items = sale.items || [];
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-2xl rounded-2xl bg-white text-gray-800 shadow-2xl print:shadow-none print:rounded-none">
        <div className="flex items-center justify-between border-b p-4 print:hidden">
          <span className="font-bold text-gray-900">Print Invoice</span>
          <div className="flex gap-2">
            <button onClick={() => window.print()} className="rounded-lg bg-orange-500 px-4 py-2 text-sm text-white hover:bg-orange-600">
              <Printer size={14} className="mr-1 inline" /> Print
            </button>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-700"><X size={20} /></button>
          </div>
        </div>
        <div className="p-6 print:p-2" id="print-area">
          {/* Colored header bar */}
          <div className="mb-4 rounded-xl px-4 py-3 flex items-center justify-between" style={{ backgroundColor: headerColor }}>
            <div className="flex items-center gap-3">
              {businessLogo && <img src={businessLogo} alt="logo" className="h-10 w-10 rounded-lg object-cover bg-white/20" />}
              <div>
                <h2 className="text-xl font-bold text-white">{businessName}</h2>
                {businessAddress && <p className="text-xs text-white/80">{businessAddress}</p>}
                {businessPhone && <p className="text-xs text-white/80">{businessPhone}</p>}
              </div>
            </div>
            <div className="text-right">
              <p className="text-lg font-bold text-white">INVOICE</p>
              <p className="text-xs text-white/80">{invoicePrefix}{sale.invoice_number || sale.id}</p>
            </div>
          </div>
          <div className="mb-4 grid grid-cols-2 gap-4 text-sm">
            <div>
              <p className="font-semibold text-gray-700">Bill To:</p>
              <p>{sale.customer_name || sale.party_name || "Walk-in"}</p>
            </div>
            <div className="text-right">
              <p>Date: <span className="font-medium">{sale.sale_date || sale.date}</span></p>
              {sale.due_date && <p>Due: <span className="font-medium">{sale.due_date}</span></p>}
            </div>
          </div>
          <table className="w-full text-sm border-collapse mb-4">
            <thead>
              <tr className="border-b-2 border-gray-300 bg-gray-50">
                <th className="py-2 text-left pl-1">Item</th>
                <th className="py-2 text-right">Qty</th>
                <th className="py-2 text-right">Unit Price</th>
                <th className="py-2 text-right">Discount</th>
                <th className="py-2 text-right pr-1">Total</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item, i) => {
                const rowTotal = (item.quantity * item.unit_price) - (item.discount_amount || 0);
                return (
                  <tr key={i} className="border-b border-gray-200">
                    <td className="py-2 pl-1">{item.product_name || item.name}</td>
                    <td className="py-2 text-right">{item.quantity}</td>
                    <td className="py-2 text-right">Rs. {parseFloat(item.unit_price).toFixed(2)}</td>
                    <td className="py-2 text-right">Rs. {parseFloat(item.discount_amount || 0).toFixed(2)}</td>
                    <td className="py-2 text-right pr-1">Rs. {rowTotal.toFixed(2)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <div className="ml-auto w-56 text-sm space-y-1">
            <div className="flex justify-between"><span>Subtotal</span><span>Rs. {parseFloat(sale.subtotal || sale.total_amount || 0).toFixed(2)}</span></div>
            {parseFloat(sale.discount || 0) > 0 && (
              <div className="flex justify-between text-red-500"><span>Discount</span><span>- Rs. {parseFloat(sale.discount).toFixed(2)}</span></div>
            )}
            <div className="flex justify-between font-bold border-t pt-1"><span>Grand Total</span><span>Rs. {parseFloat(sale.total_amount || sale.total || 0).toFixed(2)}</span></div>
            <div className="flex justify-between text-green-600"><span>Paid</span><span>Rs. {parseFloat(sale.paid_amount || 0).toFixed(2)}</span></div>
            <div className="flex justify-between text-red-500 font-semibold"><span>Balance Due</span><span>Rs. {(parseFloat(sale.total_amount || sale.total || 0) - parseFloat(sale.paid_amount || 0)).toFixed(2)}</span></div>
          </div>
          {sale.notes && (
            <div className="mt-4 text-xs text-gray-500 border-t pt-2">Notes: {sale.notes}</div>
          )}
          {footerText && (
            <div className="mt-4 border-t pt-3 text-center text-xs text-gray-400 italic">{footerText}</div>
          )}
        </div>
      </div>
    </div>
  );
}

/* ─── Sale Modal (New/Edit) ─── */
function SaleModal({ onClose, onSaved, editData }) {
  const { language } = useAppSettings();
  const [form, setForm] = useState(editData ? {
    customer_id: editData.customer_id || "",
    customer_name: editData.customer_name || editData.party_name || "",
    invoice_number: editData.invoice_number || "",
    sale_date: editData.sale_date || editData.date || today(),
    due_date: editData.due_date || "",
    items: editData.items?.length ? editData.items : [{ ...EMPTY_ITEM }],
    discount: editData.discount || 0,
    paid_amount: editData.paid_amount || 0,
    payment_method: editData.payment_method || "Cash",
    notes: editData.notes || "",
    status: editData.status || "CONFIRMED",
  } : { ...EMPTY_FORM, items: [{ ...EMPTY_ITEM }] });

  const [customers, setCustomers] = useState([]);
  const [products, setProducts] = useState([]);
  const [customerSearch, setCustomerSearch] = useState(form.customer_name);
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    parties.list({ party_type: "CUSTOMER" }).then(r => setCustomers(r.data.results ?? r.data)).catch(() => {});
    inventory.products().then(r => setProducts(r.data.results ?? r.data)).catch(() => {});
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
        items[i].unit_price = parseFloat(prod.selling_price || prod.price || 0);
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
    if (!form.customer_id && !form.customer_name) { setError("Please select a customer."); return; }
    setSaving(true);
    try {
      const payload = {
        ...form,
        status: statusOverride || form.status,
        subtotal: subtotal.toFixed(2),
        total_amount: grandTotal.toFixed(2),
        due_amount: balanceDue.toFixed(2),
      };
      if (editData?.id) {
        await salesApi.update(editData.id, payload);
      } else {
        await salesApi.create(payload);
      }
      onSaved();
    } catch (e) {
      setError(e.response?.data?.detail || "Failed to save. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  const filteredCustomers = customers.filter(c =>
    c.name?.toLowerCase().includes(customerSearch?.toLowerCase() || "")
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-2 sm:p-4">
      <div className="w-full max-w-3xl max-h-[95vh] flex flex-col rounded-2xl bg-navy-900 border border-navy-800 shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-navy-800 p-5 shrink-0">
          <h2 className="text-lg font-bold text-white">{editData ? "Edit Invoice" : "New Invoice"}</h2>
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
              {showCustomerDropdown && filteredCustomers.length > 0 && (
                <div className="absolute z-10 mt-1 w-full rounded-lg border border-navy-700 bg-navy-800 shadow-lg max-h-48 overflow-y-auto">
                  {filteredCustomers.slice(0, 20).map(c => (
                    <button key={c.id} className="w-full px-3 py-2 text-left text-sm text-white hover:bg-navy-700"
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
                <div className="col-span-4">Product</div>
                <div className="col-span-2 text-right">Qty</div>
                <div className="col-span-2 text-right">Price</div>
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
              <div>
                <label className="mb-1 block text-xs font-semibold text-navy-400">Overall Discount (Rs.)</label>
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
                    {PM_CONSTS.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
                  </select>
                </div>
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
  const [search, setSearch] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [editSale, setEditSale] = useState(null);
  const [printSale, setPrintSale] = useState(null);
  const [deleteSale, setDeleteSale] = useState(null);

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
  const totalSales = monthSales.reduce((s, x) => s + parseFloat(x.total_amount || 0), 0);
  const totalReceivable = saleList.reduce((s, x) => s + parseFloat(x.due_amount || 0), 0);
  const overdueCount = saleList.filter(s => s.status === "OVERDUE").length;

  const TABS = ["ALL", "DRAFT", "CONFIRMED", "OVERDUE"];

  const filtered = saleList.filter(s => {
    const matchTab = tab === "ALL" || s.status === tab;
    const q = search.toLowerCase();
    const matchSearch = !q || (s.invoice_number || "").toLowerCase().includes(q) ||
      (s.customer_name || s.party_name || "").toLowerCase().includes(q);
    return matchTab && matchSearch;
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

  const shareWhatsApp = (sale) => {
    const msg = `Invoice #${sale.invoice_number || sale.id}\nCustomer: ${sale.customer_name || sale.party_name || "Walk-in"}\nDate: ${sale.sale_date || sale.date}\nTotal: Rs. ${parseFloat(sale.total_amount || 0).toFixed(2)}\nPaid: Rs. ${parseFloat(sale.paid_amount || 0).toFixed(2)}\nDue: Rs. ${parseFloat(sale.due_amount || 0).toFixed(2)}\nStatus: ${sale.status}`;
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
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
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
              <div className="col-span-3">Customer</div>
              <div className="col-span-2">Date</div>
              <div className="col-span-1 text-right">Total</div>
              <div className="col-span-1 text-right">Paid</div>
              <div className="col-span-1 text-right">Due</div>
              <div className="col-span-1">Status</div>
              <div className="col-span-1 text-right">Actions</div>
            </div>
            {filtered.map(sale => (
              <div key={sale.id}
                className="grid grid-cols-12 gap-2 items-center px-4 py-3 border-t border-navy-800/50 hover:bg-navy-800/30 transition text-sm">
                <div className="col-span-12 sm:col-span-2 font-semibold text-orange-400">
                  #{sale.invoice_number || sale.id}
                </div>
                <div className="col-span-12 sm:col-span-3 text-white truncate">
                  {sale.customer_name || sale.party_name || "Walk-in"}
                </div>
                <div className="col-span-12 sm:col-span-2 text-navy-400 text-xs">
                  {formatDate(sale.sale_date || sale.date, dateMode, language)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-white font-medium">
                  {maskAmount(parseFloat(sale.total_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-green-400 text-xs">
                  {maskAmount(parseFloat(sale.paid_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-4 sm:col-span-1 text-right text-orange-400 text-xs">
                  {maskAmount(parseFloat(sale.due_amount || 0), v => `Rs. ${v.toLocaleString()}`)}
                </div>
                <div className="col-span-6 sm:col-span-1">
                  <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-semibold ${STATUS_COLORS[sale.status] || "bg-navy-700 text-navy-400"}`}>
                    {sale.status || "DRAFT"}
                  </span>
                </div>
                <div className="col-span-6 sm:col-span-1 flex justify-end gap-1">
                  <button onClick={() => { setEditSale(sale); setShowModal(true); }} title="Edit"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Edit2 size={13} />
                  </button>
                  <button onClick={() => duplicateSale(sale)} title="Duplicate Invoice"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-orange-400">
                    <Copy size={13} />
                  </button>
                  <button onClick={() => setPrintSale(sale)} title="Print"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-white">
                    <Printer size={13} />
                  </button>
                  <button onClick={() => shareWhatsApp(sale)} title="Share WhatsApp"
                    className="p-1.5 rounded-lg hover:bg-navy-700 text-navy-500 hover:text-green-400">
                    <Share2 size={13} />
                  </button>
                  <button onClick={() => setDeleteSale(sale)} title="Delete"
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
          onSaved={() => { setShowModal(false); setEditSale(null); load(); }}
        />
      )}
      {printSale && <PrintModal sale={printSale} onClose={() => setPrintSale(null)} />}
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
