import { useEffect, useState } from "react";
import ItemFormModal from "../components/item/ItemFormModal";
import {
  getItems,
  getItemStats,
  createItem,
  updateItem,
  deleteItem,
} from "../services/itemService";

export default function ItemsPage() {
  const [items, setItems] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editData, setEditData] = useState(null);

  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("");
  const [stockFilter, setStockFilter] = useState("All Stock");

  const fetchData = async () => {
    setLoading(true);
    try {
      const [itemsRes, statsRes] = await Promise.all([
        getItems({
          search,
          category: categoryFilter,
          stock: stockFilter.toLowerCase().replace(" ", ""),
        }),
        getItemStats(),
      ]);

      setItems(itemsRes.items || []);
      setStats(statsRes);
    } catch (err) {
      console.error("Error fetching items:", err);
      alert("Failed to load items. Please login again.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [search, categoryFilter, stockFilter]);

  const handleSubmit = async (formData) => {
    try {
      if (editData) {
        await updateItem(editData._id, formData);
      } else {
        await createItem(formData);
      }
      setModalOpen(false);
      setEditData(null);
      fetchData();
    } catch (err) {
      console.error(err);
      alert(err.response?.data?.message || "Failed to save item");
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Move this item to recycle bin?")) return;
    try {
      await deleteItem(id);
      fetchData();
    } catch (err) {
      alert("Failed to delete item");
    }
  };

  return (
    <div className="p-6 space-y-6 bg-slate-950 min-h-screen text-white">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">Items List ({items.length})</h1>
          <p className="text-slate-400 mt-1">Manage your products and inventory</p>
        </div>
        <button
          onClick={() => {
            setEditData(null);
            setModalOpen(true);
          }}
          className="bg-emerald-600 hover:bg-emerald-500 px-6 py-3 rounded-2xl font-semibold flex items-center gap-2 transition"
        >
          + Add New Item
        </button>
      </div>

      {/* Stats Cards */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-slate-900 border border-slate-700 rounded-3xl p-6">
            <p className="text-slate-400">Total Items</p>
            <p className="text-4xl font-bold mt-2">{stats.totalItems}</p>
          </div>
          <div className="bg-slate-900 border border-slate-700 rounded-3xl p-6">
            <p className="text-slate-400">Stock Value</p>
            <p className="text-4xl font-bold mt-2">Rs. {stats.totalStockValue.toLocaleString()}</p>
          </div>
          <div className="bg-slate-900 border border-amber-500/30 rounded-3xl p-6">
            <p className="text-amber-400">Low Stock</p>
            <p className="text-4xl font-bold mt-2 text-amber-400">{stats.lowStockItems}</p>
          </div>
          <div className="bg-slate-900 border border-red-500/30 rounded-3xl p-6">
            <p className="text-red-400">Out of Stock</p>
            <p className="text-4xl font-bold mt-2 text-red-400">{stats.outOfStockItems}</p>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="flex flex-wrap gap-3 bg-slate-900 border border-slate-700 rounded-3xl p-4">
        <input
          type="text"
          placeholder="Search by name, SKU or category..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="flex-1 bg-slate-950 border border-slate-600 rounded-2xl px-5 py-3 focus:outline-none focus:border-emerald-500"
        />

        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
          className="bg-slate-950 border border-slate-600 rounded-2xl px-5 py-3"
        >
          <option value="">All Categories</option>
          <option value="General">General</option>
          <option value="Vegetable">Vegetable</option>
          <option value="Fast Food">Fast Food</option>
          <option value="Grocery">Grocery</option>
        </select>

        <select
          value={stockFilter}
          onChange={(e) => setStockFilter(e.target.value)}
          className="bg-slate-950 border border-slate-600 rounded-2xl px-5 py-3"
        >
          <option value="All Stock">All Stock</option>
          <option value="Low Stock">Low Stock</option>
          <option value="Out of Stock">Out of Stock</option>
        </select>
      </div>

      {/* Items Table */}
      <div className="bg-slate-900 border border-slate-700 rounded-3xl overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="bg-slate-950 text-left text-slate-400 text-sm border-b border-slate-700">
              <th className="px-6 py-5">Item Name</th>
              <th className="px-6 py-5">Category</th>
              <th className="px-6 py-5">SKU</th>
              <th className="px-6 py-5">Sale Price</th>
              <th className="px-6 py-5">Purchase Price</th>
              <th className="px-6 py-5">Stock</th>
              <th className="px-6 py-5 text-center">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800">
            {loading ? (
              <tr>
                <td colSpan="7" className="text-center py-12 text-slate-400">Loading items...</td>
              </tr>
            ) : items.length === 0 ? (
              <tr>
                <td colSpan="7" className="text-center py-12 text-slate-400">No items found</td>
              </tr>
            ) : (
              items.map((item) => {
                const isLow = item.stockQty > 0 && item.stockQty <= (item.lowStockAlertAt || 0);
                const isOut = item.stockQty <= 0;

                return (
                  <tr key={item._id} className="hover:bg-slate-800/50">
                    <td className="px-6 py-5 font-medium">{item.name}</td>
                    <td className="px-6 py-5 text-slate-300">{item.category || "General"}</td>
                    <td className="px-6 py-5 text-slate-400">{item.sku || "--"}</td>
                    <td className="px-6 py-5 font-medium text-emerald-400">Rs. {item.salePrice}</td>
                    <td className="px-6 py-5 font-medium">Rs. {item.purchasePrice}</td>
                    <td className="px-6 py-5">
                      <span className={isOut ? "text-red-400" : isLow ? "text-amber-400" : "text-white"}>
                        {item.stockQty} {item.unit}
                      </span>
                    </td>
                    <td className="px-6 py-5 text-center">
                      <button
                        onClick={() => {
                          setEditData(item);
                          setModalOpen(true);
                        }}
                        className="text-emerald-400 hover:text-emerald-300 mr-4"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(item._id)}
                        className="text-red-400 hover:text-red-300"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Add / Edit Modal */}
      <ItemFormModal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setEditData(null);
        }}
        onSubmit={handleSubmit}
        editData={editData}
      />
    </div>
  );
}