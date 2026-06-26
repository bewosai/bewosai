import { useState, useEffect } from "react";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { useTranslation } from "../utils/translations";
import { usePrivateAmount } from "../context/AppSettingsContext";
import { inventory as inventoryApi } from "../api";
import {
  Package, Plus, Search, AlertTriangle, X, Tag,
  Layers, Ruler, ChevronDown, ChevronUp, Edit2, ArrowUpDown,
} from "lucide-react";

/* ── Field style ── */
const F = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";

/* ── Unit management modal (primary + secondary) ── */
function UnitModal({ onClose, onSaved, units }) {
  const { t } = useTranslation();
  const [form, setForm] = useState({
    name: "", abbreviation: "",
    secondary_unit: "", secondary_abbreviation: "", conversion_factor: "",
  });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const bid = localStorage.getItem("business_id");

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setErr("Unit name is required."); return; }
    setSaving(true);
    try {
      await inventoryApi.createUnit({ ...form, business: bid });
      onSaved();
    } catch (er) {
      setErr(er.response?.data?.name?.[0] || "Failed to save unit.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">Add Unit</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {err && <p className="mb-3 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}

        <form onSubmit={submit} className="space-y-4">
          {/* Primary unit */}
          <div className="rounded-xl border border-navy-700 bg-navy-950 p-3">
            <p className="mb-2 text-xs font-semibold text-orange-400 uppercase tracking-wide">Primary Unit</p>
            <div className="grid grid-cols-2 gap-2">
              <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="Name *  e.g. Box" className={F} />
              <input value={form.abbreviation} onChange={(e) => setForm({ ...form, abbreviation: e.target.value })}
                placeholder="Short  e.g. bx" className={F} />
            </div>
          </div>

          {/* Secondary unit */}
          <div className="rounded-xl border border-navy-700 bg-navy-950 p-3">
            <p className="mb-2 text-xs font-semibold text-blue-400 uppercase tracking-wide">Secondary Unit (optional)</p>
            <p className="mb-2 text-[10px] text-navy-400">
              Define a sub-unit, e.g. 1 Box = 12 Pieces
            </p>
            <div className="grid grid-cols-2 gap-2">
              <input value={form.secondary_unit} onChange={(e) => setForm({ ...form, secondary_unit: e.target.value })}
                placeholder="Name  e.g. Piece" className={F} />
              <input value={form.secondary_abbreviation} onChange={(e) => setForm({ ...form, secondary_abbreviation: e.target.value })}
                placeholder="Short  e.g. pc" className={F} />
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

/* ── Add/Edit product modal ── */
function ProductModal({ onClose, onSaved, categories, units, initial }) {
  const { t } = useTranslation();
  const [form, setForm] = useState({
    name: "", category: "", unit: "",
    purchase_price: "", sale_price: "",
    stock_quantity: "", low_stock_threshold: "5",
    barcode: "", description: "",
    ...initial,
    category: initial?.category ?? "",
    unit: initial?.unit ?? "",
  });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const selectedUnit = units.find((u) => String(u.id) === String(form.unit));

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setErr("Product name is required."); return; }
    setSaving(true);
    try {
      const bid = localStorage.getItem("business_id");
      if (initial?.id) {
        await inventoryApi.updateProduct(initial.id, form);
      } else {
        await inventoryApi.createProduct({ ...form, business: bid });
      }
      onSaved();
    } catch { setErr("Failed to save product."); } finally { setSaving(false); }
  };

  return (
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
            <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className={F}>
              <option value="">Category</option>
              {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            <select value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })} className={F}>
              <option value="">Unit</option>
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

          <input value={form.barcode}
            onChange={(e) => setForm({ ...form, barcode: e.target.value })}
            placeholder="Barcode (optional)" className={F} />
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
  );
}

/* ── Responsive product row / card ── */
function ProductCard({ product, onEdit }) {
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

      {/* Prices row (hidden on very small screens) */}
      <div className="mt-2 flex items-center justify-between">
        <div className="flex gap-3 text-xs">
          <span className="text-navy-400">
            Buy: {maskAmount(parseFloat(product.purchase_price), (v) => `Rs. ${v.toLocaleString()}`)}
          </span>
          <span className="text-green-400">
            Sell: {maskAmount(parseFloat(product.sale_price), (v) => `Rs. ${v.toLocaleString()}`)}
          </span>
        </div>
        <button onClick={() => onEdit(product)}
          className="flex items-center gap-1 rounded-lg border border-navy-700 px-2.5 py-1 text-xs text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400">
          <Edit2 className="h-3 w-3" /> Edit
        </button>
      </div>
    </div>
  );
}

/* ── Main page ── */
export default function InventoryPage() {
  const { t } = useTranslation();
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [units, setUnits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [activeTab, setActiveTab] = useState("products"); // products | units | categories
  const [showAddProduct, setShowAddProduct] = useState(false);
  const [showAddUnit, setShowAddUnit] = useState(false);
  const [editingProduct, setEditingProduct] = useState(null);

  const load = () => {
    const bid = localStorage.getItem("business_id");
    setLoading(true);
    Promise.all([
      inventoryApi.products({ business: bid }),
      inventoryApi.categories({ business: bid }),
      inventoryApi.units({ business: bid }),
    ])
      .then(([p, c, u]) => {
        setProducts(p.data.results ?? p.data);
        setCategories(c.data.results ?? c.data);
        setUnits(u.data.results ?? u.data);
      })
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  const filtered = products.filter((p) =>
    p.name.toLowerCase().includes(search.toLowerCase())
  );
  const lowStockCount = products.filter((p) => p.is_low_stock).length;

  return (
    <div>
      <PageHeader
        title={t("inventory")}
        subtitle="Manage products, categories, units, and stock levels."
        action={
          <div className="flex gap-2">
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
          <div className="mb-4 flex items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-2">
            <Search className="h-4 w-4 shrink-0 text-navy-500" />
            <input value={search} onChange={(e) => setSearch(e.target.value)}
              placeholder="Search products…"
              className="flex-1 bg-transparent text-sm text-white outline-none placeholder:text-navy-500" />
            {search && <button onClick={() => setSearch("")}><X className="h-4 w-4 text-navy-400" /></button>}
          </div>
          {lowStockCount > 0 && (
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
                  onEdit={(prod) => { setEditingProduct(prod); setShowAddProduct(true); }} />
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <Package className="h-12 w-12 text-navy-700" />
              <p className="text-sm text-navy-400">
                {search ? "No products match your search." : "No products yet."}
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
                  </div>
                </div>
              ))}
            </div>
          )}
        </SectionCard>
      )}

      {/* Categories tab */}
      {activeTab === "categories" && (
        <SectionCard title={`Categories (${categories.length})`}>
          {categories.length === 0 ? (
            <p className="py-6 text-center text-sm text-navy-400">No categories yet.</p>
          ) : (
            <div className="flex flex-wrap gap-2 py-2">
              {categories.map((c) => (
                <span key={c.id} className="rounded-xl border border-navy-700 bg-navy-950 px-3 py-2 text-sm font-medium text-white">
                  {c.name}
                </span>
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
    </div>
  );
}
