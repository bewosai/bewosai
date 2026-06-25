import { useState, useEffect } from "react";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { inventory as inventoryApi } from "../api";
import { Package, Plus, Search, AlertTriangle, Barcode, Tag, X } from "lucide-react";

function ProductRow({ product, onEdit }) {
  const lowStock = product.is_low_stock;
  return (
    <div className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3 transition hover:border-navy-700">
      <div className="flex items-center gap-3 min-w-0">
        <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ${lowStock ? "bg-red-500/15" : "bg-orange-500/10"}`}>
          <Package className={`h-4 w-4 ${lowStock ? "text-red-400" : "text-orange-400"}`} />
        </div>
        <div className="min-w-0">
          <p className="truncate text-sm font-medium text-white">{product.name}</p>
          <p className="text-xs text-navy-400">
            {product.category_name || "Uncategorised"} · {product.unit_name || "–"}
          </p>
        </div>
      </div>
      <div className="ml-4 shrink-0 text-right">
        <p className={`text-sm font-semibold ${lowStock ? "text-red-400" : "text-white"}`}>
          {product.stock_quantity} {lowStock && <span className="text-xs">(low)</span>}
        </p>
        <p className="text-xs text-navy-400">Rs. {Number(product.sale_price).toLocaleString()}</p>
      </div>
    </div>
  );
}

function AddProductModal({ onClose, onSaved, categories, units }) {
  const [form, setForm] = useState({
    name: "", category: "", unit: "",
    purchase_price: "", sale_price: "",
    stock_quantity: "", low_stock_threshold: "5",
    barcode: "",
  });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");

  const handle = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setErr("Product name is required."); return; }
    setSaving(true);
    try {
      const bid = localStorage.getItem("business_id");
      await inventoryApi.createProduct({ ...form, business: bid });
      onSaved();
    } catch {
      setErr("Failed to save product.");
    } finally {
      setSaving(false);
    }
  };

  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-lg rounded-2xl border border-navy-700 bg-navy-900 p-6 shadow-2xl">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="text-base font-bold text-white">Add Product</h2>
          <button onClick={onClose} className="text-navy-400 hover:text-white"><X className="h-5 w-5" /></button>
        </div>
        {err && <p className="mb-4 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}
        <form onSubmit={submit} className="space-y-3">
          <input name="name" value={form.name} onChange={handle} placeholder="Product name *" className={field} />
          <div className="grid grid-cols-2 gap-3">
            <select name="category" value={form.category} onChange={handle} className={field}>
              <option value="">Category</option>
              {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            <select name="unit" value={form.unit} onChange={handle} className={field}>
              <option value="">Unit</option>
              {units.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
            </select>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <input name="purchase_price" value={form.purchase_price} onChange={handle} placeholder="Purchase price" type="number" className={field} />
            <input name="sale_price" value={form.sale_price} onChange={handle} placeholder="Sale price" type="number" className={field} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <input name="stock_quantity" value={form.stock_quantity} onChange={handle} placeholder="Opening stock" type="number" className={field} />
            <input name="low_stock_threshold" value={form.low_stock_threshold} onChange={handle} placeholder="Low stock alert" type="number" className={field} />
          </div>
          <input name="barcode" value={form.barcode} onChange={handle} placeholder="Barcode (optional)" className={field} />
          <div className="flex gap-3 pt-1">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>
              {saving ? "Saving…" : "Add Product"}
            </PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>Cancel</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function InventoryPage() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [units, setUnits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [showAdd, setShowAdd] = useState(false);

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
        title="Inventory"
        subtitle="Manage products, categories, and stock levels."
        action={
          <PrimaryButton onClick={() => setShowAdd(true)}>
            <Plus className="h-4 w-4" /> Add Product
          </PrimaryButton>
        }
      />

      {/* Summary */}
      <div className="mb-6 grid gap-4 sm:grid-cols-3">
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-xs text-navy-400">Total Products</p>
          <p className="mt-1 text-2xl font-bold text-white">{products.length}</p>
        </div>
        <div className={`rounded-2xl border p-4 ${lowStockCount > 0 ? "border-red-500/30 bg-red-500/5" : "border-navy-800 bg-navy-900"}`}>
          <p className="text-xs text-navy-400">Low Stock</p>
          <p className={`mt-1 text-2xl font-bold ${lowStockCount > 0 ? "text-red-400" : "text-white"}`}>{lowStockCount}</p>
          {lowStockCount > 0 && <p className="text-xs text-red-400">Needs restocking</p>}
        </div>
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-4">
          <p className="text-xs text-navy-400">Categories</p>
          <p className="mt-1 text-2xl font-bold text-white">{categories.length}</p>
        </div>
      </div>

      <SectionCard title="Products">
        <div className="mb-4 flex items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-2">
          <Search className="h-4 w-4 text-navy-500" />
          <input
            value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Search products…"
            className="flex-1 bg-transparent text-sm text-white outline-none placeholder:text-navy-500"
          />
        </div>

        {loading ? (
          <p className="py-6 text-center text-sm text-navy-400">Loading products…</p>
        ) : filtered.length ? (
          <div className="space-y-2">
            {filtered.map((p) => <ProductRow key={p.id} product={p} />)}
          </div>
        ) : (
          <div className="flex flex-col items-center gap-3 py-10 text-center">
            <Package className="h-12 w-12 text-navy-700" />
            <p className="text-sm text-navy-400">
              {search ? "No products match your search." : "No products yet."}
            </p>
            {!search && (
              <PrimaryButton onClick={() => setShowAdd(true)}>
                <Plus className="h-4 w-4" /> Add First Product
              </PrimaryButton>
            )}
          </div>
        )}
      </SectionCard>

      {showAdd && (
        <AddProductModal
          categories={categories}
          units={units}
          onClose={() => setShowAdd(false)}
          onSaved={() => { setShowAdd(false); load(); }}
        />
      )}
    </div>
  );
}
