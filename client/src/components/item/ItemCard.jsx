import { formatCurrency } from "../../utils/format";

export default function ItemCard({ item, onEdit, onDelete }) {
  const isLowStock =
    Number(item.stockQty || 0) <= Number(item.lowStockAlertAt || 0);
  const isOutOfStock = Number(item.stockQty || 0) <= 0;

  const stockValue =
    Number(item.stockQty || 0) * Number(item.purchasePrice || 0);

  const profitPerUnit =
    Number(item.salePrice || 0) - Number(item.purchasePrice || 0);

  const expectedProfit = Number(item.stockQty || 0) * profitPerUnit;

  return (
    <div className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-lg shadow-black/20">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="text-lg font-bold text-white">{item.name}</h3>
          <p className="mt-1 text-sm text-slate-400">
            {item.sku || "No code"} • {item.unit}
          </p>
        </div>

        <span
          className={`rounded-full px-3 py-1 text-xs font-medium ${
            item.status === "active"
              ? "bg-emerald-500/15 text-emerald-300"
              : "bg-slate-700 text-slate-300"
          }`}
        >
          {item.status}
        </span>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
        <Info label="Category" value={item.category || "-"} />
        <Info label="Brand" value={item.brand || "-"} />
        <Info label="Purchase" value={formatCurrency(item.purchasePrice)} />
        <Info label="Sale" value={formatCurrency(item.salePrice)} />
        <Info label="Stock" value={`${item.stockQty} ${item.unit}`} />
        <Info label="Stock Value" value={formatCurrency(stockValue)} />
        <Info label="Profit / Unit" value={formatCurrency(profitPerUnit)} />
        <Info label="Expected Profit" value={formatCurrency(expectedProfit)} />
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        {isOutOfStock ? (
          <Badge text="Out of stock" tone="red" />
        ) : isLowStock ? (
          <Badge text="Low stock" tone="amber" />
        ) : (
          <Badge text="In stock" tone="green" />
        )}

        {item.taxRate > 0 && (
          <Badge text={`Tax ${item.taxRate}%`} tone="blue" />
        )}
      </div>

      <div className="mt-5 flex gap-2">
        <button
          onClick={() => onEdit(item)}
          className="flex-1 rounded-2xl border border-slate-700 px-3 py-2 text-sm text-slate-200"
        >
          Edit
        </button>

        <button
          onClick={() => onDelete(item)}
          className="flex-1 rounded-2xl border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-300"
        >
          Delete
        </button>
      </div>
    </div>
  );
}

function Info({ label, value }) {
  return (
    <div>
      <p className="text-xs uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 text-sm text-slate-200">{value}</p>
    </div>
  );
}

function Badge({ text, tone }) {
  const styles = {
    green: "bg-emerald-500/15 text-emerald-300",
    amber: "bg-amber-500/15 text-amber-300",
    red: "bg-red-500/15 text-red-300",
    blue: "bg-blue-500/15 text-blue-300",
  };

  return (
    <span className={`rounded-full px-3 py-1 text-xs font-medium ${styles[tone]}`}>
      {text}
    </span>
  );
}