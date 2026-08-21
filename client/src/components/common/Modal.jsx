import { X } from "lucide-react";
import { useEscToClose } from "../../hooks/useEscToClose";

/**
 * Reusable modal container.
 * Props: title, onClose, size ("sm" | "md" | "lg" | "xl"), children, footer
 */
export default function Modal({ title, onClose, size = "md", children, footer }) {
  useEscToClose(onClose);

  const widths = {
    sm: "max-w-md",
    md: "max-w-xl",
    lg: "max-w-3xl",
    xl: "max-w-5xl",
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div
        className={`w-full ${widths[size]} max-h-[95vh] flex flex-col rounded-2xl border border-navy-800 bg-navy-900 shadow-2xl`}
      >
        {/* Header */}
        <div className="flex shrink-0 items-center justify-between border-b border-navy-800 px-5 py-4">
          <h2 className="text-base font-bold text-white">{title}</h2>
          <button
            onClick={onClose}
            className="rounded-lg p-1 text-navy-500 transition hover:bg-navy-800 hover:text-white"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-5 py-4">{children}</div>

        {/* Footer */}
        {footer && (
          <div className="shrink-0 border-t border-navy-800 px-5 py-4">{footer}</div>
        )}
      </div>
    </div>
  );
}
