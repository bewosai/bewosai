import { useEffect, useState } from "react";

const CATEGORY_OPTIONS = [
  "General", "Grocery", "Vegetable", "Fruit", "Dairy", 
  "Beverages", "Snacks", "Fast Food", "Bakery", "Stationery", 
  "Electronics", "Clothing", "Hardware", "Medicine", "Household", "Other"
];

const COMMON_UNITS = [
  "pcs", "kg", "gram", "liter", "ml", "dozen", "packet", 
  "box", "bag", "set", "meter", "kilogram", "piece", "bottle", "can"
];

const initialForm = {
  name: "",
  sku: "",
  category: "General",
  type: "Product",           // Product or Service
  primaryUnit: "pcs",
  secondaryUnit: "",
  conversionRate: 1,
  salePrice: 0,
  purchasePrice: 0,
  openingStock: 0,
  lowStockAlert: 10,
  notes: "",
};

export default function ItemFormModal({ 
  open, 
  onClose, 
  onSubmit, 
  editData, 
  loading = false 
}) {
  const [form, setForm] = useState(initialForm);
  const [activeTab, setActiveTab] = useState("stock"); // stock | others
  const [unitModalOpen, setUnitModalOpen] = useState(false);

  // Load edit data
  useEffect(() => {
    if (editData) {
      setForm({
        name: editData.name || "",
        sku: editData.sku || "",
        category: editData.category || "General",
        type: editData.type || "Product",
        primaryUnit: editData.primaryUnit || "pcs",
        secondaryUnit: editData.secondaryUnit || "",
        conversionRate: editData.conversionRate || 1,
        salePrice: editData.salePrice || 0,
        purchasePrice: editData.purchasePrice || 0,
        openingStock: editData.stockQty || 0,
        lowStockAlert: editData.lowStockAlertAt || 10,
        notes: editData.notes || "",
      });
    } else {
      setForm({ ...initialForm });
    }
    setActiveTab("stock");
  }, [editData, open]);

  if (!open) return null;

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm(prev => ({
      ...prev,
      [name]: ["salePrice", "purchasePrice", "openingStock", "lowStockAlert", "conversionRate"].includes(name)
        ? Number(value) || 0
        : value
    }));
  };

  const handleUnitSave = (primary, secondary, rate) => {
    setForm(prev => ({
      ...prev,
      primaryUnit: primary,
      secondaryUnit: secondary,
      conversionRate: rate
    }));
    setUnitModalOpen(false);
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit({
      name: form.name,
      sku: form.sku,
      category: form.category,
      type: form.type,
      primaryUnit: form.primaryUnit,
      secondaryUnit: form.secondaryUnit,
      conversionRate: form.conversionRate,
      salePrice: form.salePrice,
      purchasePrice: form.purchasePrice,
      stockQty: form.openingStock,
      lowStockAlertAt: form.lowStockAlert,
      notes: form.notes,
    });
  };

  const profitPerUnit = form.salePrice - form.purchasePrice;
  const stockValue = form.openingStock * form.purchasePrice;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-2xl bg-white rounded-3xl shadow-2xl overflow-hidden">

        {/* Header */}
        <div className="px-8 py-6 border-b flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-semibold text-gray-900">
              {editData ? "Edit Item" : "Add New Item"}
            </h2>
            <p className="text-sm text-gray-500 mt-1">Fill details carefully for accurate stock & profit tracking</p>
          </div>
          <button onClick={onClose} className="text-3xl text-gray-400 hover:text-gray-600">×</button>
        </div>

        <form onSubmit={handleSubmit} className="p-8 space-y-8">

          {/* Item Name */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Item Name <span className="text-red-500">*</span></label>
            <input
              type="text"
              name="name"
              value={form.name}
              onChange={handleChange}
              placeholder="eg. Apple, Rice 5kg, Wai Wai Noodles"
              required
              className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl focus:outline-none focus:border-emerald-500 text-base"
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Category */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Category</label>
              <select
                name="category"
                value={form.category}
                onChange={handleChange}
                className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl focus:outline-none focus:border-emerald-500"
              >
                {CATEGORY_OPTIONS.map(cat => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>

            {/* Type */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Item Type</label>
              <div className="flex gap-3">
                {["Product", "Service"].map(t => (
                  <button
                    key={t}
                    type="button"
                    onClick={() => setForm(p => ({ ...p, type: t }))}
                    className={`flex-1 py-3.5 rounded-2xl font-medium transition-all ${
                      form.type === t 
                        ? "bg-emerald-500 text-white shadow" 
                        : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                    }`}
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Tabs */}
          <div className="flex border-b border-gray-200">
            <button
              type="button"
              onClick={() => setActiveTab("stock")}
              className={`flex-1 pb-4 text-sm font-semibold border-b-2 transition-all ${
                activeTab === "stock" ? "border-emerald-500 text-emerald-600" : "border-transparent text-gray-500"
              }`}
            >
              Stock Details
            </button>
            <button
              type="button"
              onClick={() => setActiveTab("others")}
              className={`flex-1 pb-4 text-sm font-semibold border-b-2 transition-all ${
                activeTab === "others" ? "border-emerald-500 text-emerald-600" : "border-transparent text-gray-500"
              }`}
            >
              Others
            </button>
          </div>

          {/* ====================== STOCK DETAILS TAB ====================== */}
          {activeTab === "stock" && (
            <div className="space-y-6">
              {/* Measuring Unit */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Measuring Unit</label>
                <button
                  type="button"
                  onClick={() => setUnitModalOpen(true)}
                  className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl text-left hover:border-emerald-500 transition flex justify-between items-center bg-white"
                >
                  <span className="text-base">
                    {form.primaryUnit}
                    {form.secondaryUnit && ` / ${form.secondaryUnit} (${form.conversionRate})`}
                  </span>
                  <span className="text-emerald-500 text-sm font-medium">Change Unit →</span>
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Opening Stock</label>
                  <input
                    type="number"
                    name="openingStock"
                    value={form.openingStock}
                    onChange={handleChange}
                    placeholder="0"
                    className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Sales Price (₹)</label>
                  <input
                    type="number"
                    name="salePrice"
                    value={form.salePrice}
                    onChange={handleChange}
                    step="0.01"
                    className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Purchase Price (₹)</label>
                  <input
                    type="number"
                    name="purchasePrice"
                    value={form.purchasePrice}
                    onChange={handleChange}
                    step="0.01"
                    className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Low Stock Alert Level</label>
                  <input
                    type="number"
                    name="lowStockAlert"
                    value={form.lowStockAlert}
                    onChange={handleChange}
                    placeholder="10"
                    className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>
            </div>
          )}

          {/* ====================== OTHERS TAB ====================== */}
          {activeTab === "others" && (
            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">SKU / Item Code (Optional)</label>
                <input
                  type="text"
                  name="sku"
                  value={form.sku}
                  onChange={handleChange}
                  placeholder="eg. APPLE-FRESH-1KG"
                  className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Notes / Remarks</label>
                <textarea
                  name="notes"
                  value={form.notes}
                  onChange={handleChange}
                  rows={5}
                  placeholder="Size, flavor, supplier, expiry info, etc."
                  className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl focus:outline-none focus:border-emerald-500 resize-y"
                />
              </div>
            </div>
          )}

          {/* Live Calculation Box */}
          <div className="bg-emerald-50 border border-emerald-100 rounded-2xl p-6">
            <div className="grid grid-cols-2 gap-8">
              <div>
                <p className="text-gray-500 text-sm">Profit Per Unit</p>
                <p className="text-2xl font-semibold text-emerald-600 mt-1">₹{profitPerUnit.toFixed(2)}</p>
              </div>
              <div>
                <p className="text-gray-500 text-sm">Stock Value</p>
                <p className="text-2xl font-semibold text-gray-900 mt-1">₹{stockValue.toFixed(2)}</p>
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex gap-4 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-4 border border-gray-300 rounded-2xl text-gray-700 font-medium hover:bg-gray-50 transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 py-4 bg-emerald-500 hover:bg-emerald-600 disabled:bg-emerald-300 text-white font-semibold rounded-2xl transition"
            >
              {loading ? "Saving..." : editData ? "Update Item" : "Add Item"}
            </button>
          </div>
        </form>
      </div>

      {/* ====================== MEASURING UNIT MODAL ====================== */}
      <UnitSelectionModal
        open={unitModalOpen}
        onClose={() => setUnitModalOpen(false)}
        onSave={handleUnitSave}
        initialPrimary={form.primaryUnit}
        initialSecondary={form.secondaryUnit}
        initialRate={form.conversionRate}
      />
    </div>
  );
}

/* ====================== UNIT SELECTION MODAL ====================== */
function UnitSelectionModal({ open, onClose, onSave, initialPrimary, initialSecondary, initialRate }) {
  const [primaryUnit, setPrimaryUnit] = useState(initialPrimary || "kg");
  const [secondaryUnit, setSecondaryUnit] = useState(initialSecondary || "");
  const [conversionRate, setConversionRate] = useState(initialRate || 1000);

  if (!open) return null;

  const handleSave = () => {
    onSave(primaryUnit, secondaryUnit, conversionRate);
  };

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/70 p-4">
      <div className="bg-white rounded-3xl w-full max-w-md p-8">
        <h3 className="text-xl font-semibold mb-6">Select Measuring Unit</h3>

        <div className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Primary Unit</label>
            <select
              value={primaryUnit}
              onChange={(e) => setPrimaryUnit(e.target.value)}
              className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl"
            >
              {COMMON_UNITS.map(u => (
                <option key={u} value={u}>{u}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Secondary Unit (Optional)</label>
            <select
              value={secondaryUnit}
              onChange={(e) => setSecondaryUnit(e.target.value)}
              className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl"
            >
              <option value="">None</option>
              {COMMON_UNITS.map(u => (
                <option key={u} value={u}>{u}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Conversion Rate (1 {primaryUnit} = ? {secondaryUnit || "secondary unit"})
            </label>
            <input
              type="number"
              value={conversionRate}
              onChange={(e) => setConversionRate(Number(e.target.value))}
              className="w-full px-5 py-3.5 border border-gray-300 rounded-2xl"
              placeholder="1000"
            />
          </div>
        </div>

        <div className="flex gap-4 mt-8">
          <button
            onClick={onClose}
            className="flex-1 py-3.5 border border-gray-300 rounded-2xl text-gray-700 font-medium hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="flex-1 py-3.5 bg-emerald-500 text-white rounded-2xl font-medium hover:bg-emerald-600"
          >
            Save Unit
          </button>
        </div>
      </div>
    </div>
  );
}