import { AlertTriangle } from "lucide-react";
import { useEscToClose } from "../../hooks/useEscToClose";

/**
 * Reusable confirmation dialog.
 * Props: message, confirmLabel, confirmCls, onConfirm, onCancel
 */
export default function ConfirmDialog({
  message,
  confirmLabel = "Delete",
  confirmCls = "bg-red-500 hover:bg-red-600 text-white",
  onConfirm,
  onCancel,
}) {
  useEscToClose(onCancel);

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-2xl border border-navy-800 bg-navy-900 p-6 shadow-2xl">
        <div className="mb-4 flex items-start gap-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-red-500/10">
            <AlertTriangle className="h-5 w-5 text-red-400" />
          </div>
          <p className="pt-1 text-sm text-navy-200">{message}</p>
        </div>
        <div className="flex justify-end gap-3">
          <button
            onClick={onCancel}
            className="rounded-xl border border-navy-700 px-4 py-2 text-sm text-navy-400 transition hover:bg-navy-800 hover:text-white"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className={`rounded-xl px-4 py-2 text-sm font-semibold transition ${confirmCls}`}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
