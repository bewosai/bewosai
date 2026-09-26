import { useState, useEffect } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount } from "../context/AppSettingsContext";
import { inventory as inventoryApi } from "../api";
import {
  Package, Plus, Search, AlertTriangle, X, Tag,
  Layers, Ruler, ChevronDown, ChevronUp, Edit2, ArrowUpDown, Trash2,
  Upload, Download,
} from "lucide-react";
import ConfirmDialog from "../components/common/ConfirmDialog";
import { todayStr } from "../utils/dates";

/* ── Export current products to .xlsx — same columns the bulk-import
   template uses, so an exported file can be edited and re-imported. ── */
async function exportProductsToExcel(products) {
  // Loaded on click: the spreadsheet library is large, and opening this page
  // shouldn't download it just in case someone exports.
  const XLSX = await import("xlsx");
  const headers = ["name", "category", "unit", "sale_price", "purchase_price", "stock_quantity", "low_stock_threshold", "barcode", "hs_code", "description"];
  const rows = products.map(p => [
    p.name, p.category_name || "", p.unit_name || "", p.sale_price, p.purchase_price,
    p.stock_quantity, p.low_stock_threshold, p.barcode || "", p.hs_code || "", p.description || "",
  ]);
  const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
  ws["!cols"] = headers.map(() => ({ wch: 20 }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Products");
  XLSX.writeFile(wb, `products_export_${todayStr()}.xlsx`);
}

/* ── Field style ── */
const F = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";

// Common unit names offered as suggestions (via <datalist>) in both the
// primary and secondary unit fields — still a plain text input underneath,
// so typing anything not on this list just defines a new unit of your own.
const STANDARD_UNITS = [
  "Bag", "Bottle", "Box", "Carton", "Centimeter", "Dozen", "Gram", "Gross",
  "Kilogram", "Liter", "Meter", "Milliliter", "Pack", "Pair", "Piece",
  "Quintal", "Ream", "Roll", "Set", "Sheet", "Square Feet", "Square Meter", "Ton",
];

// Well-known primary -> secondary conversions, auto-filled the moment the
// primary unit name matches one of these (case-insensitively) — the same
// pairings shown next to each unit in the list below (e.g. "Dozen = 12.0000
// Piece"). Only fills fields that are still blank, so it never overwrites a
// conversion the user already typed themselves.
const STANDARD_CONVERSIONS = {
  dozen:    { secondary_unit: "Piece",      secondary_abbreviation: "pc", conversion_factor: "12" },
  gross:    { secondary_unit: "Piece",      secondary_abbreviation: "pc", conversion_factor: "144" },
  kilogram: { secondary_unit: "Gram",       secondary_abbreviation: "g",  conversion_factor: "1000" },
  liter:    { secondary_unit: "Milliliter", secondary_abbreviation: "ml", conversion_factor: "1000" },
  meter:    { secondary_unit: "Centimeter", secondary_abbreviation: "cm", conversion_factor: "100" },
  pair:     { secondary_unit: "Piece",      secondary_abbreviation: "pc", conversion_factor: "2" },
  quintal:  { secondary_unit: "Kilogram",   secondary_abbreviation: "kg", conversion_factor: "100" },
  ream:     { secondary_unit: "Sheet",      secondary_abbreviation: "sh", conversion_factor: "500" },
  ton:      { secondary_unit: "Kilogram",   secondary_abbreviation: "kg", conversion_factor: "1000" },
};

/* ── Unit management modal (primary + secondary) ── */
function UnitModal({ onClose, onSaved, units, initial }) {
  const { t } = useTranslation();
  const [form, setForm] = useState({
    name: initial?.name || "", abbreviation: initial?.abbreviation || "",
    secondary_unit: initial?.secondary_unit || "",
    secondary_abbreviation: initial?.secondary_abbreviation || "",
    conversion_factor: initial?.conversion_factor ?? "",
  });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const bid = localStorage.getItem("business_id");

  // Fires once the primary name field loses focus — picking (or typing)
  // e.g. "Kilogram" auto-fills Secondary = Gram, factor = 1000, without
  // clobbering anything the user already entered by hand.
  const applyStandardConversion = () => {
    const known = STANDARD_CONVERSIONS[form.name.trim().toLowerCase()];
    if (!known) return;
    setForm((f) => ({
      ...f,
      secondary_unit: f.secondary_unit || known.secondary_unit,
      secondary_abbreviation: f.secondary_abbreviation || known.secondary_abbreviation,
      conversion_factor: f.conversion_factor || known.conversion_factor,
    }));
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setErr("Unit name is required."); return; }
    setSaving(true);
    try {
      const { data } = initial?.id
        ? await inventoryApi.updateUnit(initial.id, form)
        : await inventoryApi.createUnit({ ...form, business: bid });
      onSaved(data);
    } catch (er) {
      setErr(er.response?.data?.name?.[0] || "Failed to save unit.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-60 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{initial?.id ? "Edit Unit" : "Add Unit"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {err && <p className="mb-3 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}

        <form onSubmit={submit} className="space-y-4">
          {/* Backs the "Name" fields above — a native dropdown of common
              units, but still a free-text input underneath, so typing
              something not on this list just defines your own unit. */}
          <datalist id="bw-unit-suggestions">
            {STANDARD_UNITS.map((u) => <option key={u} value={u} />)}
          </datalist>

          {/* Primary unit */}
          <div className="rounded-xl border border-navy-700 bg-navy-950 p-3">
            <p className="mb-2 text-xs font-semibold text-orange-400 uppercase tracking-wide">Primary Unit</p>
            <div className="grid grid-cols-2 gap-2">
              <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })}
                onBlur={applyStandardConversion}
                list="bw-unit-suggestions"
                placeholder="Name *" className={F} />
              <input value={form.abbreviation} onChange={(e) => setForm({ ...form, abbreviation: e.target.value })}
                placeholder="Short" className={F} />
            </div>
          </div>

          {/* Secondary unit */}
          <div className="rounded-xl border border-navy-700 bg-navy-950 p-3">
            <p className="mb-2 text-xs font-semibold text-blue-400 uppercase tracking-wide">Secondary Unit (optional)</p>
            <p className="mb-2 text-[10px] text-navy-400">
              Define a sub-unit — picking a standard primary unit (Dozen, Kilogram, Liter…) auto-fills this
            </p>
            <div className="grid grid-cols-2 gap-2">
              <input value={form.secondary_unit} onChange={(e) => setForm({ ...form, secondary_unit: e.target.value })}
                list="bw-unit-suggestions"
                placeholder="Name" className={F} />
              <input value={form.secondary_abbreviation} onChange={(e) => setForm({ ...form, secondary_abbreviation: e.target.value })}
                placeholder="Short" className={F} />
            </div>
            {form.secondary_unit && (
              <input type="number" min="0" step="0.0001"
                value={form.conversion_factor}
                onChange={(e) => setForm({ ...form, conversion_factor: e.target.value })}
                placeholder={`How many ${form.secondary_unit || "secondary"} per 1 ${form.name || "primary"}?`}
                className={`${F} mt-2`}
              />
            )}
          </div>

          {/* Existing units */}
          {units.length > 0 && (
            <div>
              <p className="mb-1.5 text-xs text-navy-400">Existing units</p>
              <div className="flex flex-wrap gap-1.5">
                {units.map((u) => (
                  <span key={u.id} className="rounded-lg border border-navy-700 bg-navy-950 px-2.5 py-1 text-xs text-white">
                    {u.display || u.name}
                    {u.secondary_unit && (
                      <span className="ml-1 text-navy-400">= {u.conversion_factor} {u.secondary_unit}</span>
                    )}
                  </span>
                ))}
              </div>
            </div>
          )}

          <div className="flex gap-3 pt-1">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>{saving ? "Saving…" : t("save")}</PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>{t("cancel")}</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ── Add/Edit category modal ── */
function CategoryModal({ onClose, onSaved, categories, initial }) {
  const [name, setName] = useState(initial?.name || "");
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const bid = localStorage.getItem("business_id");

  const submit = async (e) => {
    e.preventDefault();
    if (!name.trim()) { setErr("Category name is required."); return; }
    setSaving(true);
    try {
      const { data } = initial?.id
        ? await inventoryApi.updateCategory(initial.id, { name: name.trim() })
        : await inventoryApi.createCategory({ name: name.trim(), business: bid });
      onSaved(data);
    } catch (er) {
      setErr(er.response?.data?.name?.[0] || "Failed to save category.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-60 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-sm rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="font-bold text-white">{initial?.id ? "Edit Category" : "Add Category"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {err && <p className="mb-3 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}
        {categories.length > 0 && (
          <div className="mb-4">
            <p className="mb-2 text-xs text-navy-400">Existing categories</p>
            <div className="flex flex-wrap gap-1.5">
              {categories.map(c => (
                <span key={c.id} className="rounded-lg border border-navy-700 bg-navy-950 px-2.5 py-1 text-xs text-white">{c.name}</span>
              ))}
            </div>
          </div>
        )}
        <form onSubmit={submit} className="space-y-3">
          <input value={name} onChange={e => setName(e.target.value)} placeholder="Category name *" className={F} />
          <div className="flex gap-3">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>{saving ? "Saving…" : "Add Category"}</PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>Cancel</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ── Add/Edit product modal ── */
function ProductModal({ onClose, onSaved, categories, units, initial, onCategoryCreated, onUnitCreated }) {
  const { t } = useTranslation();
  const [form, setForm] = useState({
    name: "", purchase_price: "", sale_price: "",
    stock_quantity: "", low_stock_threshold: "5",
    barcode: "", hs_code: "", description: "",
    ...initial,
    category: initial?.category ?? "",
    unit: initial?.unit ?? "",
  });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  // So a product's category/unit can be created on the spot instead of
  // cancelling this form to go manage them separately first.
  const [showQuickAddCategory, setShowQuickAddCategory] = useState(false);
  const [showQuickAddUnit, setShowQuickAddUnit] = useState(false);
  const selectedUnit = units.find((u) => String(u.id) === String(form.unit));

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setErr("Product name is required."); return; }
    setSaving(true);
    try {
      const bid = localStorage.getItem("business_id");
      // This form has no image upload — `initial` (spread into form state
      // above) carries the server's existing image URL as a plain string,
      // which DRF's ImageField rejects if sent back as-is in the payload.
      const { image, ...payload } = form;
      if (initial?.id) {
        await inventoryApi.updateProduct(initial.id, payload);
      } else {
        await inventoryApi.createProduct({ ...payload, business: bid });
      }
      onSaved();
    } catch { setErr("Failed to save product."); } finally { setSaving(false); }
  };

  return (
    <>
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-lg rounded-2xl border border-navy-700 bg-navy-900 p-6 max-h-[90vh] overflow-y-auto shadow-2xl">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{initial?.id ? "Edit Product" : "Add Product"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {err && <p className="mb-3 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}
        <form onSubmit={submit} className="space-y-3">
          <input name="name" value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Product name *" className={F} />

          <div className="grid grid-cols-2 gap-3">
            <select value={form.category} onChange={(e) => {
              if (e.target.value === "__new__") { setShowQuickAddCategory(true); return; }
              setForm({ ...form, category: e.target.value });
            }} className={F}>
              <option value="">Category</option>
              <option value="__new__">+ Add New Category</option>
              {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            <select value={form.unit} onChange={(e) => {
              if (e.target.value === "__new__") { setShowQuickAddUnit(true); return; }
              setForm({ ...form, unit: e.target.value });
            }} className={F}>
              <option value="">Unit</option>
              <option value="__new__">+ Add New Unit</option>
              {units.map((u) => (
                <option key={u.id} value={u.id}>{u.display || u.name}</option>
              ))}
            </select>
          </div>

          {/* Show secondary unit info if unit selected has one */}
          {selectedUnit?.secondary_unit && (
            <div className="flex items-center gap-2 rounded-xl border border-blue-500/20 bg-blue-500/5 px-3 py-2 text-xs text-blue-300">
              <ArrowUpDown className="h-3.5 w-3.5 shrink-0" />
              1 {selectedUnit.name} = {selectedUnit.conversion_factor} {selectedUnit.secondary_unit}
              <span className="text-navy-400">(stock tracked in {selectedUnit.name})</span>
            </div>
          )}

          <div className="grid grid-cols-2 gap-3">
            <div>
              <p className="mb-1 text-xs text-navy-400">Purchase Price</p>
              <input value={form.purchase_price}
                onChange={(e) => setForm({ ...form, purchase_price: e.target.value })}
                placeholder="0.00" type="number" step="0.01" className={F} />
            </div>
            <div>
              <p className="mb-1 text-xs text-navy-400">Sale Price</p>
              <input value={form.sale_price}
                onChange={(e) => setForm({ ...form, sale_price: e.target.value })}
                placeholder="0.00" type="number" step="0.01" className={F} />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <p className="mb-1 text-xs text-navy-400">Opening Stock</p>
              <input value={form.stock_quantity}
                onChange={(e) => setForm({ ...form, stock_quantity: e.target.value })}
                placeholder="0" type="number" step="0.001" className={F} />
            </div>
            <div>
              <p className="mb-1 text-xs text-navy-400">Low Stock Alert</p>
              <input value={form.low_stock_threshold}
                onChange={(e) => setForm({ ...form, low_stock_threshold: e.target.value })}
                placeholder="5" type="number" className={F} />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <input value={form.barcode}
              onChange={(e) => setForm({ ...form, barcode: e.target.value })}
              placeholder="Barcode (optional)" className={F} />
            <input value={form.hs_code}
              onChange={(e) => setForm({ ...form, hs_code: e.target.value })}
              placeholder="HS Code (optional)" className={F} />
          </div>
          <textarea value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
            placeholder="Description (optional)" rows={2} className={`${F} resize-none`} />

          <div className="flex gap-3 pt-1">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>
              {saving ? "Saving…" : (initial?.id ? "Save Changes" : "Add Product")}
            </PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>{t("cancel")}</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
    {showQuickAddCategory && (
      <CategoryModal
        categories={categories}
        onClose={() => setShowQuickAddCategory(false)}
        onSaved={(created) => {
          onCategoryCreated(created);
          setForm((f) => ({ ...f, category: created.id }));
          setShowQuickAddCategory(false);
        }}
      />
    )}
    {showQuickAddUnit && (
      <UnitModal
        units={units}
        onClose={() => setShowQuickAddUnit(false)}
        onSaved={(created) => {
          onUnitCreated(created);
          setForm((f) => ({ ...f, unit: created.id }));
          setShowQuickAddUnit(false);
        }}
      />
    )}
    </>
  );
}

/* ── Stock Adjustment Modal ── */
function StockAdjustModal({ product, onClose, onSaved }) {
  const bid = localStorage.getItem("business_id");
  const [form, setForm] = useState({ movement_type: "IN", quantity: "", note: "" });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");

  const TYPES = [
    { value: "IN",          label: "Stock In",      color: "bg-green-500/10 text-green-400" },
    { value: "OPENING",     label: "Opening Stock", color: "bg-orange-500/10 text-orange-400" },
    { value: "ADJUSTMENT",  label: "Adjustment",    color: "bg-blue-500/10 text-blue-400" },
    { value: "DAMAGE",      label: "Damage",        color: "bg-red-500/10 text-red-400" },
    { value: "LOST",        label: "Lost",          color: "bg-red-500/10 text-red-400" },
    { value: "OUT",         label: "Manual Out",    color: "bg-navy-700/50 text-navy-300" },
    { value: "TRANSFER",    label: "Transfer Out",  color: "bg-purple-500/10 text-purple-400" },
  ];

  const isNegative = ["OUT", "DAMAGE", "LOST", "TRANSFER"].includes(form.movement_type);

  const submit = async (e) => {
    e.preventDefault();
    if (!form.quantity || parseFloat(form.quantity) <= 0) { setErr("Enter a valid quantity."); return; }
    setSaving(true);
    try {
      // Backend already subtracts for OUT/DAMAGE/LOST/TRANSFER and adds for
      // IN/OPENING, so always send a positive magnitude — pre-negating here
      // would make the backend's subtraction add stock back instead.
      const qty = Math.abs(parseFloat(form.quantity));
      await inventoryApi.addStockMovement({
        product: product.id,
        movement_type: form.movement_type,
        quantity: qty,
        note: form.note,
        business: bid,
      });
      onSaved();
    } catch (e) {
      setErr(e.response?.data?.detail || "Failed to save adjustment.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 shadow-2xl">
        <div className="flex items-center justify-between border-b border-navy-800 px-5 py-4">
          <div>
            <h2 className="font-bold text-white">Stock Adjustment</h2>
            <p className="text-xs text-navy-400 mt-0.5">{product.name} · Current: {product.stock_quantity} {product.unit_name || "units"}</p>
          </div>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        <form onSubmit={submit} className="p-5 space-y-4">
          {err && <p className="rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}

          {/* Type selector grid */}
          <div>
            <p className="mb-2 text-xs font-semibold text-navy-400">Adjustment Type</p>
            <div className="grid grid-cols-2 gap-2">
              {TYPES.map(t => (
                <button
                  key={t.value} type="button"
                  onClick={() => setForm(f => ({ ...f, movement_type: t.value }))}
                  className={`rounded-xl border px-3 py-2 text-xs font-semibold transition ${
                    form.movement_type === t.value
                      ? `${t.color} border-current`
                      : "border-navy-700 text-navy-400 hover:border-navy-600"
                  }`}
                >
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-navy-400">
              Quantity {isNegative ? "(to subtract)" : "(to add)"} *
            </p>
            <input
              type="number" min="0.001" step="0.001"
              className={F}
              placeholder="0"
              value={form.quantity}
              onChange={e => setForm(f => ({ ...f, quantity: e.target.value }))}
            />
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-navy-400">Note / Reason</p>
            <textarea
              rows={2} className={`${F} resize-none`}
              placeholder="Reason for adjustment…"
              value={form.note}
              onChange={e => setForm(f => ({ ...f, note: e.target.value }))}
            />
          </div>

          <div className="flex gap-3">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>
              {saving ? "Saving…" : "Save Adjustment"}
            </PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>Cancel</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ── Responsive product row / card ── */
function ProductCard({ product, onEdit, onAdjust, onDelete }) {
  const maskAmount = usePrivateAmount();
  const lowStock = product.is_low_stock;
  const unit = product.unit_name || "";

  return (
    <div className={`rounded-xl border bg-navy-950 px-4 py-3 transition hover:border-navy-700 ${
      lowStock ? "border-red-500/30" : "border-navy-800"
    }`}>
      {/* Mobile: stacked; desktop: row */}
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-center gap-3 min-w-0">
          <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ${
            lowStock ? "bg-red-500/15" : "bg-orange-500/10"
          }`}>
            <Package className={`h-4 w-4 ${lowStock ? "text-red-400" : "text-orange-400"}`} />
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold text-white">{product.name}</p>
            <p className="text-xs text-navy-400">
              {product.category_name || "No category"} · {unit || "–"}
            </p>
          </div>
        </div>

        <div className="shrink-0 text-right">
          <p className={`text-sm font-bold ${lowStock ? "text-red-400" : "text-white"}`}>
            {product.stock_quantity} {unit}
            {lowStock && <span className="ml-1 text-xs text-red-400">Low</span>}
          </p>
          <p className="text-xs text-navy-400">
            {maskAmount(parseFloat(product.sale_price), (v) => `Rs. ${v.toLocaleString()}`)}
          </p>
        </div>
      </div>

      {/* Prices row */}
      <div className="mt-2 flex items-center justify-between">
        <div className="flex gap-3 text-xs">
          <span className="text-navy-400">
            Buy: {maskAmount(parseFloat(product.purchase_price), (v) => `Rs. ${v.toLocaleString()}`)}
          </span>
          <span className="text-green-400">
            Sell: {maskAmount(parseFloat(product.sale_price), (v) => `Rs. ${v.toLocaleString()}`)}
          </span>
        </div>
        <div className="flex gap-1.5">
          <button onClick={() => onAdjust(product)}
            className="flex items-center gap-1 rounded-lg border border-navy-700 px-2.5 py-1 text-xs text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400">
            <Layers className="h-3 w-3" /> Adjust
          </button>
          <button onClick={() => onEdit(product)}
            className="flex items-center gap-1 rounded-lg border border-navy-700 px-2.5 py-1 text-xs text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400">
            <Edit2 className="h-3 w-3" /> Edit
          </button>
          <button onClick={() => onDelete(product)}
            className="flex items-center gap-1 rounded-lg border border-navy-700 px-2.5 py-1 text-xs text-navy-300 transition hover:border-red-500/50 hover:text-red-400">
            <Trash2 className="h-3 w-3" />
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Main page ── */
export default function InventoryPage() {
  const { t } = useTranslation();
  const location = useLocation();
  const navigate = useNavigate();
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [units, setUnits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [activeTab, setActiveTab] = useState("products"); // products | units | categories
  const [lowStockOnly, setLowStockOnly] = useState(false);
  const [showAddProduct, setShowAddProduct] = useState(false);
  const [showAddUnit, setShowAddUnit] = useState(false);
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [editingProduct, setEditingProduct] = useState(null);
  const [adjustingProduct, setAdjustingProduct] = useState(null);
  const [deletingProduct, setDeletingProduct] = useState(null);
  const [editingUnit, setEditingUnit] = useState(null);
  const [deletingUnit, setDeletingUnit] = useState(null);
  const [editingCategory, setEditingCategory] = useState(null);
  const [deletingCategory, setDeletingCategory] = useState(null);
  const [deleteError, setDeleteError] = useState("");

  // The Sidebar / Dashboard link to specific inventory views by URL
  // (/inventory/low-stock, /inventory/categories, ...) — without this the
  // page always opened on the Products tab regardless of which link was
  // clicked, silently dropping the user's intent.
  useEffect(() => {
    if (location.pathname === "/inventory/low-stock") {
      setActiveTab("products");
      setLowStockOnly(true);
    } else if (location.pathname === "/inventory/categories") {
      setActiveTab("categories");
    } else if (location.pathname === "/inventory/stock") {
      setActiveTab("units");
    }
  }, [location.pathname]);

  const load = () => {
    const bid = localStorage.getItem("business_id");
    setLoading(true);
    Promise.all([
      inventoryApi.products({ business: bid, page_size: 1000 }),
      inventoryApi.categories({ business: bid, page_size: 1000 }),
      inventoryApi.units({ business: bid, page_size: 1000 }),
    ])
      .then(([p, c, u]) => {
        setProducts(p.data.results ?? p.data);
        setCategories(c.data.results ?? c.data);
        setUnits(u.data.results ?? u.data);
      })
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  const filtered = products.filter((p) => {
    const q = search.toLowerCase();
    const matchesSearch = !q || p.name.toLowerCase().includes(q) || (p.barcode || "").toLowerCase().includes(q);
    return matchesSearch && (!lowStockOnly || p.is_low_stock);
  });
  const lowStockCount = products.filter((p) => p.is_low_stock).length;

  return (
    <div>
      <PageHeader
        title={t("inventory")}
        subtitle="Manage products, categories, units, and stock levels."
        action={
          <div className="flex flex-wrap gap-2">
            <PrimaryButton variant="outline" onClick={() => exportProductsToExcel(products)} disabled={products.length === 0}>
              <Download className="h-4 w-4" /> Export
            </PrimaryButton>
            <PrimaryButton variant="outline" onClick={() => navigate("/import?type=products")}>
              <Upload className="h-4 w-4" /> Bulk Import
            </PrimaryButton>
            <PrimaryButton variant="outline" onClick={() => setShowAddCategory(true)}>
              <Tag className="h-4 w-4" /> Category
            </PrimaryButton>
            <PrimaryButton variant="outline" onClick={() => setShowAddUnit(true)}>
              <Ruler className="h-4 w-4" /> Unit
            </PrimaryButton>
            <PrimaryButton onClick={() => { setEditingProduct(null); setShowAddProduct(true); }}>
              <Plus className="h-4 w-4" /> Product
            </PrimaryButton>
          </div>
        }
      />

      {/* Summary */}
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-xs text-navy-400">Products</p>
          <p className="mt-1 text-2xl font-bold text-white">{products.length}</p>
        </div>
        <div className={`rounded-2xl border p-4 ${lowStockCount > 0 ? "border-red-500/30 bg-red-500/5" : "border-navy-800 bg-navy-900"}`}>
          <p className="text-xs text-navy-400">Low Stock</p>
          <p className={`mt-1 text-2xl font-bold ${lowStockCount > 0 ? "text-red-400" : "text-white"}`}>{lowStockCount}</p>
        </div>
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-xs text-navy-400">Categories</p>
          <p className="mt-1 text-2xl font-bold text-white">{categories.length}</p>
        </div>
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-xs text-navy-400">Units</p>
          <p className="mt-1 text-2xl font-bold text-white">{units.length}</p>
        </div>
      </div>

      {deleteError && (
        <div className="mb-4 flex items-center justify-between gap-2 rounded-xl border border-red-500/20 bg-red-500/5 px-3 py-2 text-xs text-red-400">
          <span className="flex items-center gap-2"><AlertTriangle className="h-3.5 w-3.5 shrink-0" /> {deleteError}</span>
          <button onClick={() => setDeleteError("")}><X className="h-3.5 w-3.5" /></button>
        </div>
      )}

      {/* Tabs */}
      <div className="mb-4 flex gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1 w-fit">
        {[
          { key: "products", label: "Products", icon: Package },
          { key: "units",    label: "Units",    icon: Ruler },
          { key: "categories", label: "Categories", icon: Tag },
        ].map(({ key, label, icon: Icon }) => (
          <button key={key} onClick={() => setActiveTab(key)}
            className={`flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold transition ${
              activeTab === key ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"
            }`}
          >
            <Icon className="h-3.5 w-3.5" /> {label}
          </button>
        ))}
      </div>

      {/* Products tab */}
      {activeTab === "products" && (
        <SectionCard title={`Products (${filtered.length})`}>
          <div className="mb-3 flex items-center gap-2">
            <div className="flex flex-1 items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-2">
              <Search className="h-4 w-4 shrink-0 text-navy-500" />
              <input value={search} onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by name or barcode…"
                className="flex-1 bg-transparent text-sm text-white outline-none placeholder:text-navy-500" />
              {search && <button onClick={() => setSearch("")}><X className="h-4 w-4 text-navy-400" /></button>}
            </div>
            <button onClick={() => setLowStockOnly((v) => !v)}
              className={`flex shrink-0 items-center gap-1.5 rounded-xl border px-3 py-2 text-xs font-semibold transition ${
                lowStockOnly ? "border-red-500/40 bg-red-500/10 text-red-400" : "border-navy-700 text-navy-400 hover:text-white"
              }`}>
              <AlertTriangle className="h-3.5 w-3.5" /> Low Stock Only
            </button>
          </div>
          {lowStockCount > 0 && !lowStockOnly && (
            <div className="mb-3 flex items-center gap-2 rounded-xl border border-red-500/20 bg-red-500/5 px-3 py-2 text-xs text-red-400">
              <AlertTriangle className="h-3.5 w-3.5 shrink-0" />
              {lowStockCount} product{lowStockCount > 1 ? "s" : ""} running low on stock
            </div>
          )}
          {loading ? (
            <p className="py-6 text-center text-sm text-navy-400">{t("loading")}</p>
          ) : filtered.length ? (
            <div className="space-y-2">
              {filtered.map((p) => (
                <ProductCard key={p.id} product={p}
                  onEdit={(prod) => { setEditingProduct(prod); setShowAddProduct(true); }}
                  onAdjust={(prod) => setAdjustingProduct(prod)}
                  onDelete={(prod) => setDeletingProduct(prod)}
                />
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <Package className="h-12 w-12 text-navy-700" />
              <p className="text-sm text-navy-400">
                {search
                  ? "No products match your search."
                  : lowStockOnly
                  ? "No products are running low on stock."
                  : "No products yet."}
              </p>
              {!search && (
                <PrimaryButton onClick={() => { setEditingProduct(null); setShowAddProduct(true); }}>
                  <Plus className="h-4 w-4" /> Add First Product
                </PrimaryButton>
              )}
            </div>
          )}
        </SectionCard>
      )}

      {/* Units tab */}
      {activeTab === "units" && (
        <SectionCard title={`Units (${units.length})`}
          action={
            <PrimaryButton onClick={() => setShowAddUnit(true)}>
              <Plus className="h-4 w-4" /> Add Unit
            </PrimaryButton>
          }
        >
          {units.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <Ruler className="h-12 w-12 text-navy-700" />
              <p className="text-sm text-navy-400">No units defined yet.</p>
              <PrimaryButton onClick={() => setShowAddUnit(true)}><Plus className="h-4 w-4" /> Add Unit</PrimaryButton>
            </div>
          ) : (
            <div className="space-y-2">
              {units.map((u) => (
                <div key={u.id} className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3">
                  <div className="flex items-center gap-3">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-orange-500/10">
                      <Ruler className="h-4 w-4 text-orange-400" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-white">
                        {u.name}
                        {u.abbreviation && <span className="ml-1.5 text-xs text-navy-400">({u.abbreviation})</span>}
                      </p>
                      {u.secondary_unit && (
                        <p className="text-xs text-blue-300">
                          1 {u.name} = {u.conversion_factor} {u.secondary_unit}
                          {u.secondary_abbreviation && ` (${u.secondary_abbreviation})`}
                        </p>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {u.secondary_unit && (
                      <span className="rounded-lg border border-blue-500/20 bg-blue-500/10 px-2 py-0.5 text-[10px] font-semibold text-blue-300">
                        Dual Unit
                      </span>
                    )}
                    <button onClick={() => setEditingUnit(u)}
                      className="rounded-lg border border-navy-700 p-1.5 text-navy-400 transition hover:border-orange-500/50 hover:text-orange-400">
                      <Edit2 className="h-3.5 w-3.5" />
                    </button>
                    <button onClick={() => setDeletingUnit(u)}
                      className="rounded-lg border border-navy-700 p-1.5 text-navy-400 transition hover:border-red-500/50 hover:text-red-400">
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </SectionCard>
      )}

      {/* Categories tab */}
      {activeTab === "categories" && (
        <SectionCard title={`Categories (${categories.length})`}
          action={
            <PrimaryButton onClick={() => setShowAddCategory(true)}>
              <Plus className="h-4 w-4" /> Add Category
            </PrimaryButton>
          }
        >
          {categories.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <Tag className="h-12 w-12 text-navy-700" />
              <p className="text-sm text-navy-400">No categories yet.</p>
              <PrimaryButton onClick={() => setShowAddCategory(true)}><Plus className="h-4 w-4" /> Add Category</PrimaryButton>
            </div>
          ) : (
            <div className="flex flex-wrap gap-2 py-2">
              {categories.map((c) => (
                <div key={c.id} className="flex items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 pl-3 pr-1.5 py-1.5 text-sm font-medium text-white">
                  {c.name}
                  <button onClick={() => setEditingCategory(c)}
                    className="rounded-lg p-1 text-navy-400 transition hover:text-orange-400">
                    <Edit2 className="h-3 w-3" />
                  </button>
                  <button onClick={() => setDeletingCategory(c)}
                    className="rounded-lg p-1 text-navy-400 transition hover:text-red-400">
                    <Trash2 className="h-3 w-3" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </SectionCard>
      )}

      {/* Modals */}
      {showAddProduct && (
        <ProductModal
          initial={editingProduct}
          categories={categories}
          units={units}
          onCategoryCreated={(c) => setCategories((prev) => [...prev, c])}
          onUnitCreated={(u) => setUnits((prev) => [...prev, u])}
          onClose={() => { setShowAddProduct(false); setEditingProduct(null); }}
          onSaved={() => { setShowAddProduct(false); setEditingProduct(null); load(); }}
        />
      )}
      {showAddUnit && (
        <UnitModal
          units={units}
          onClose={() => setShowAddUnit(false)}
          onSaved={() => { setShowAddUnit(false); load(); }}
        />
      )}
      {editingUnit && (
        <UnitModal
          initial={editingUnit}
          units={units}
          onClose={() => setEditingUnit(null)}
          onSaved={() => { setEditingUnit(null); load(); }}
        />
      )}
      {showAddCategory && (
        <CategoryModal
          categories={categories}
          onClose={() => setShowAddCategory(false)}
          onSaved={() => { setShowAddCategory(false); load(); }}
        />
      )}
      {editingCategory && (
        <CategoryModal
          initial={editingCategory}
          categories={categories}
          onClose={() => setEditingCategory(null)}
          onSaved={() => { setEditingCategory(null); load(); }}
        />
      )}
      {adjustingProduct && (
        <StockAdjustModal
          product={adjustingProduct}
          onClose={() => setAdjustingProduct(null)}
          onSaved={() => { setAdjustingProduct(null); load(); }}
        />
      )}
      {deletingProduct && (
        <ConfirmDialog
          message={`Delete product "${deletingProduct.name}"? It will be moved to Recycle Bin.`}
          onConfirm={async () => {
            setDeleteError("");
            try {
              await inventoryApi.deleteProduct(deletingProduct.id);
              load();
            } catch (err) {
              setDeleteError(err.response?.data?.error || err.response?.data?.detail || `Could not delete "${deletingProduct.name}".`);
            }
            setDeletingProduct(null);
          }}
          onCancel={() => setDeletingProduct(null)}
        />
      )}
      {deletingUnit && (
        <ConfirmDialog
          message={`Delete unit "${deletingUnit.name}"? Products using it will keep their stock but lose this unit label.`}
          onConfirm={async () => {
            setDeleteError("");
            try {
              await inventoryApi.deleteUnit(deletingUnit.id);
              load();
            } catch (err) {
              setDeleteError(err.response?.data?.error || err.response?.data?.detail || `Could not delete "${deletingUnit.name}".`);
            }
            setDeletingUnit(null);
          }}
          onCancel={() => setDeletingUnit(null)}
        />
      )}
      {deletingCategory && (
        <ConfirmDialog
          message={`Delete category "${deletingCategory.name}"? Products using it will keep their data but lose this category label.`}
          onConfirm={async () => {
            setDeleteError("");
            try {
              await inventoryApi.deleteCategory(deletingCategory.id);
              load();
            } catch (err) {
              setDeleteError(err.response?.data?.error || err.response?.data?.detail || `Could not delete "${deletingCategory.name}".`);
            }
            setDeletingCategory(null);
          }}
          onCancel={() => setDeletingCategory(null)}
        />
      )}
    </div>
  );
}
