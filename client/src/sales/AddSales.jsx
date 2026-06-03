import { useMemo, useState } from "react";
import { createSale } from "../services/saleService";

const emptyRow = () => ({
  item: "",
  name: "",
  qty: 1,
  price: 0,
  discountPercent: 0,
  discountAmount: 0,
});

const pageWrap = "min-h-screen bg-[#0f1117] text-white p-6";
const card =
  "bg-[#12141c] border border-[#232634] rounded-2xl shadow-[0_0_0_1px_rgba(255,255,255,0.02)]";
const input =
  "w-full bg-[#0f1117] border border-[#2b2e3b] rounded-xl px-4 py-3 text-sm text-white outline-none focus:border-emerald-500";
const label = "block text-sm font-medium text-slate-200 mb-2";
const th =
  "bg-[#171923] text-left text-slate-300 text-sm font-semibold px-4 py-3 border-b border-[#2b2e3b]";
const td = "px-3 py-3 border-b border-[#232634] align-middle";
const greenBtn =
  "bg-emerald-500 hover:bg-emerald-600 text-white font-semibold px-5 py-3 rounded-xl transition";
const ghostBtn =
  "border border-[#2b2e3b] hover:bg-[#181b24] text-white font-medium px-5 py-3 rounded-xl transition";

function round2(n) {
  return Number(Number(n || 0).toFixed(2));
}

export default function AddSales() {
  const [form, setForm] = useState({
    party: "",
    invoiceNo: "",
    invoiceDate: "",
    note: "",
    paymentMode: "Cash",
    paid: 0,
    items: [emptyRow()],
  });

  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  const totals = useMemo(() => {
    const computed = form.items.map((row) => {
      const qty = Number(row.qty || 0);
      const price = Number(row.price || 0);
      const base = qty * price;
      const discountPercent = Number(row.discountPercent || 0);
      const discountAmount =
        row.discountAmount !== "" && row.discountAmount !== null
          ? Number(row.discountAmount || 0)
          : (base * discountPercent) / 100;

      const finalAmount = Math.max(0, base - discountAmount);

      return {
        ...row,
        base: round2(base),
        discountAmount: round2(discountAmount),
        finalAmount: round2(finalAmount),
      };
    });

    const subtotal = computed.reduce((s, x) => s + x.finalAmount, 0);
    const paid = Number(form.paid || 0);
    const due = Math.max(0, subtotal - paid);

    return {
      rows: computed,
      subtotal: round2(subtotal),
      paid: round2(paid),
      due: round2(due),
    };
  }, [form]);

  const updateField = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const updateRow = (index, field, value) => {
    setForm((prev) => {
      const items = [...prev.items];
      items[index] = { ...items[index], [field]: value };
      return { ...prev, items };
    });
  };

  const addRow = () => {
    setForm((prev) => ({ ...prev, items: [...prev.items, emptyRow()] }));
  };

  const removeRow = (index) => {
    setForm((prev) => {
      if (prev.items.length === 1) return prev;
      return { ...prev, items: prev.items.filter((_, i) => i !== index) };
    });
  };

  const resetForm = () => {
    setForm({
      party: "",
      invoiceNo: "",
      invoiceDate: "",
      note: "",
      paymentMode: "Cash",
      paid: 0,
      items: [emptyRow()],
    });
    setErr("");
    setMsg("");
  };

  const handleSubmit = async (saveAndNew = false) => {
    setErr("");
    setMsg("");

    if (!form.invoiceNo.trim()) {
      setErr("Invoice No is required");
      return;
    }

    if (!form.invoiceDate) {
      setErr("Invoice date is required");
      return;
    }

    const cleanedItems = totals.rows
      .filter((r) => r.name.trim())
      .map((r) => ({
        item: r.item || r.name,
        name: r.name.trim(),
        qty: Number(r.qty || 0),
        price: Number(r.price || 0),
        discount: Number(r.discountAmount || 0),
        taxRate: 0,
      }));

    if (cleanedItems.length === 0) {
      setErr("Please add at least one billing item");
      return;
    }

    if (cleanedItems.some((r) => r.qty <= 0)) {
      setErr("Quantity must be greater than 0");
      return;
    }

    try {
      setLoading(true);

      await createSale({
        party: form.party || null,
        invoiceNo: form.invoiceNo,
        invoiceDate: form.invoiceDate,
        note: form.note,
        paymentMode: form.paymentMode,
        paid: Number(form.paid || 0),
        status: "sale",
        items: cleanedItems,
      });

      setMsg("Sales invoice saved successfully");

      if (saveAndNew) {
        resetForm();
      }
    } catch (error) {
      setErr(error?.response?.data?.message || "Failed to save sales invoice");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={pageWrap}>
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center gap-3 mb-6">
          <button className="text-slate-300 text-xl">←</button>
          <h1 className="text-4xl font-bold">Create Sales Invoice</h1>
        </div>

        <div className={`${card} p-7`}>
          {msg && (
            <div className="mb-4 rounded-xl border border-emerald-600 bg-emerald-950/30 px-4 py-3 text-emerald-300">
              {msg}
            </div>
          )}

          {err && (
            <div className="mb-4 rounded-xl border border-red-600 bg-red-950/30 px-4 py-3 text-red-300">
              {err}
            </div>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-7">
            <div>
              <label className={label}>Select Party</label>
              <input
                className={input}
                placeholder="Search for party"
                value={form.party}
                onChange={(e) => updateField("party", e.target.value)}
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className={label}>Invoice No</label>
                <input
                  className={input}
                  placeholder="10"
                  value={form.invoiceNo}
                  onChange={(e) => updateField("invoiceNo", e.target.value)}
                />
              </div>

              <div>
                <label className={label}>Mode</label>
                <div className="text-emerald-400 font-semibold pt-3">Manual</div>
              </div>

              <div>
                <label className={label}>Invoice Date</label>
                <input
                  type="date"
                  className={input}
                  value={form.invoiceDate}
                  onChange={(e) => updateField("invoiceDate", e.target.value)}
                />
              </div>
            </div>
          </div>

          <div className="overflow-x-auto rounded-2xl border border-[#2b2e3b] mb-8">
            <table className="w-full min-w-[1100px]">
              <thead>
                <tr>
                  <th className={th}>S.N.</th>
                  <th className={th}>Name</th>
                  <th className={th}>Quantity</th>
                  <th className={th}>Rate</th>
                  <th className={th}>Discount %</th>
                  <th className={th}>Discount Rs.</th>
                  <th className={th}>Amount</th>
                  <th className={th}></th>
                </tr>
              </thead>
              <tbody>
                {totals.rows.map((row, index) => (
                  <tr key={index}>
                    <td className={td}>
                      <div className="text-center">{index + 1}</div>
                    </td>

                    <td className={td}>
                      <input
                        className={input}
                        placeholder="Enter Item name"
                        value={row.name}
                        onChange={(e) => updateRow(index, "name", e.target.value)}
                      />
                    </td>

                    <td className={td}>
                      <input
                        type="number"
                        className={input}
                        value={row.qty}
                        onChange={(e) => updateRow(index, "qty", e.target.value)}
                      />
                    </td>

                    <td className={td}>
                      <input
                        type="number"
                        className={input}
                        placeholder="Rs."
                        value={row.price}
                        onChange={(e) => updateRow(index, "price", e.target.value)}
                      />
                    </td>

                    <td className={td}>
                      <input
                        type="number"
                        className={input}
                        placeholder="%"
                        value={row.discountPercent}
                        onChange={(e) =>
                          updateRow(index, "discountPercent", e.target.value)
                        }
                      />
                    </td>

                    <td className={td}>
                      <input
                        type="number"
                        className={input}
                        placeholder="Rs."
                        value={row.discountAmount}
                        onChange={(e) =>
                          updateRow(index, "discountAmount", e.target.value)
                        }
                      />
                    </td>

                    <td className={td}>
                      <div className="font-semibold">Rs. {row.finalAmount.toFixed(2)}</div>
                    </td>

                    <td className={td}>
                      <button
                        type="button"
                        onClick={() => removeRow(index)}
                        className="text-red-400 hover:text-red-300"
                      >
                        🗑
                      </button>
                    </td>
                  </tr>
                ))}

                <tr>
                  <td colSpan={3} className="px-4 py-4">
                    <button
                      type="button"
                      onClick={addRow}
                      className="text-emerald-400 font-semibold hover:text-emerald-300"
                    >
                      + Add Billing Item
                    </button>
                  </td>
                  <td colSpan={5} className="px-4 py-4 text-right font-semibold text-slate-200">
                    Sub Total
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
            <div>
              <label className={label}>Notes or Remarks</label>
              <textarea
                rows={4}
                className={input}
                placeholder="Enter note or description..."
                value={form.note}
                onChange={(e) => updateField("note", e.target.value)}
              />

              <div className="mt-6">
                <div className="text-sm font-medium text-slate-200 mb-2">Attach Images</div>
                <div className="w-20 h-20 rounded-xl border border-[#2b2e3b] flex items-center justify-center text-3xl text-slate-400 bg-[#0f1117]">
                  📷
                </div>
              </div>
            </div>

            <div className="max-w-md lg:ml-auto w-full space-y-5">
              <div>
                <label className={label}>Total Amount</label>
                <div className={`${input} flex items-center font-semibold`}>
                  Rs. {totals.subtotal.toFixed(2)}
                </div>
              </div>

              <div>
                <label className={label}>Payment Mode</label>
                <select
                  className={input}
                  value={form.paymentMode}
                  onChange={(e) => updateField("paymentMode", e.target.value)}
                >
                  <option>Cash</option>
                  <option>Bank</option>
                  <option>Online</option>
                  <option>Credit</option>
                </select>
              </div>

              <div>
                <label className={label}>Paid Amount</label>
                <input
                  type="number"
                  className={input}
                  placeholder="Rs."
                  value={form.paid}
                  onChange={(e) => updateField("paid", e.target.value)}
                />
              </div>

              <div>
                <label className={label}>Due Amount</label>
                <div className={`${input} flex items-center font-semibold text-yellow-400`}>
                  Rs. {totals.due.toFixed(2)}
                </div>
              </div>
            </div>
          </div>

          <div className="flex justify-end gap-4 mt-8">
            <button
              type="button"
              disabled={loading}
              className={ghostBtn}
              onClick={() => handleSubmit(true)}
            >
              Save & New
            </button>

            <button
              type="button"
              disabled={loading}
              className={greenBtn}
              onClick={() => handleSubmit(false)}
            >
              {loading ? "Saving..." : "Save Sales Invoice"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}