import { useEffect, useState } from "react";

const initialState = {
  name: "",
  phone: "",
  email: "",
  address: "",
  type: "customer",
  openingBalance: 0,
  notes: "",
};

export default function PartyFormModal({
  open,
  onClose,
  onSubmit,
  loading = false,
  editData = null,
}) {
  const [form, setForm] = useState(initialState);

  useEffect(() => {
    if (editData) {
      setForm({
        name: editData.name || "",
        phone: editData.phone || "",
        email: editData.email || "",
        address: editData.address || "",
        type: editData.type || "customer",
        openingBalance: editData.openingBalance || 0,
        notes: editData.notes || "",
      });
    } else {
      setForm(initialState);
    }
  }, [editData, open]);

  if (!open) return null;

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => ({
      ...prev,
      [name]: name === "openingBalance" ? Number(value) : value,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    await onSubmit(form);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 px-4 py-6">
      <div className="w-full max-w-2xl rounded-2xl border border-emerald-500/20 bg-slate-900 shadow-2xl">
        <div className="flex items-center justify-between border-b border-emerald-500/20 px-5 py-4">
          <h2 className="text-lg font-semibold text-emerald-200">
            {editData ? "Edit Party" : "Add New Party"}
          </h2>
          <button
            onClick={onClose}
            className="rounded-lg border border-emerald-500/20 px-3 py-1.5 text-sm text-emerald-200 hover:bg-emerald-500/10"
          >
            Close
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-5">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <InputField
              label="Party Name"
              name="name"
              value={form.name}
              onChange={handleChange}
              required
            />
            <InputField
              label="Phone"
              name="phone"
              value={form.phone}
              onChange={handleChange}
            />
            <InputField
              label="Email"
              name="email"
              type="email"
              value={form.email}
              onChange={handleChange}
            />
            <div>
              <label className="mb-1 block text-sm text-emerald-200">Type</label>
              <select
                name="type"
                value={form.type}
                onChange={handleChange}
                className="w-full rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-3 py-2.5 text-sm text-emerald-200 outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
              >
                <option value="customer" className="text-slate-900">
                  Customer
                </option>
                <option value="supplier" className="text-slate-900">
                  Supplier
                </option>
                <option value="both" className="text-slate-900">
                  Both
                </option>
              </select>
            </div>

            <div className="md:col-span-2">
              <InputField
                label="Address"
                name="address"
                value={form.address}
                onChange={handleChange}
              />
            </div>

            <InputField
              label="Opening Balance"
              name="openingBalance"
              type="number"
              value={form.openingBalance}
              onChange={handleChange}
            />

            <div className="md:col-span-2">
              <label className="mb-1 block text-sm text-emerald-200">Notes</label>
              <textarea
                name="notes"
                rows="4"
                value={form.notes}
                onChange={handleChange}
                className="w-full rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-3 py-2.5 text-sm text-emerald-200 outline-none placeholder:text-emerald-200/60 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
                placeholder="Optional notes..."
              />
            </div>
          </div>

          <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-end">
            <button
              type="button"
              onClick={onClose}
              className="rounded-xl border border-emerald-500/20 px-4 py-2.5 text-sm font-medium text-emerald-200 hover:bg-emerald-500/10"
            >
              Cancel
            </button>

            <button
              type="submit"
              disabled={loading}
              className="rounded-xl bg-emerald-500 px-4 py-2.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {loading ? "Saving..." : editData ? "Update Party" : "Create Party"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function InputField({ label, name, value, onChange, type = "text", required = false }) {
  return (
    <div>
      <label className="mb-1 block text-sm text-emerald-200">{label}</label>
      <input
        name={name}
        type={type}
        value={value}
        required={required}
        onChange={onChange}
        className='w-full rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-3 py-2.5 text-sm text-emerald-200 outline-none placeholder:text-emerald-200/60 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20'
      />
    </div>
  );
}