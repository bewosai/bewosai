import { formatCurrency } from "../../utils/format";

export default function PartyCard({ party, onEdit, onDelete, onViewLedger }) {
  return (
    <div className="rounded-2xl border border-emerald-500/20 bg-slate-900 p-4 shadow-sm transition hover:shadow-lg">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="text-lg font-semibold text-emerald-200">{party.name}</h3>
          <p className="mt-1 text-sm text-emerald-200/70 capitalize">{party.type}</p>
        </div>

        <span className="rounded-full border border-emerald-500/20 bg-emerald-500/10 px-3 py-1 text-xs text-emerald-200">
          {formatCurrency(party.openingBalance || 0)}
        </span>
      </div>

      <div className="mt-4 space-y-2 text-sm text-emerald-200/80">
        <p><span className="font-medium">Phone:</span> {party.phone || "-"}</p>
        <p><span className="font-medium">Email:</span> {party.email || "-"}</p>
        <p><span className="font-medium">Address:</span> {party.address || "-"}</p>
      </div>

      <div className="mt-5 flex flex-wrap gap-2">
        <button
          onClick={() => onViewLedger(party)}
          className="rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-3 py-2 text-sm text-emerald-200 hover:bg-emerald-500/20"
        >
          View Ledger
        </button>

        <button
          onClick={() => onEdit(party)}
          className="rounded-xl border border-emerald-500/20 px-3 py-2 text-sm text-emerald-200 hover:bg-emerald-500/10"
        >
          Edit
        </button>

        <button
          onClick={() => onDelete(party)}
          className="rounded-xl border border-red-500/20 bg-red-500/10 px-3 py-2 text-sm text-red-300 hover:bg-red-500/20"
        >
          Delete
        </button>
      </div>
    </div>
  );
}