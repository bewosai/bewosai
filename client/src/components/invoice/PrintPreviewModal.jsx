import { Printer, X } from "lucide-react";

/**
 * Shared modal chrome around a printed bill — the "Print"/close bar (hidden
 * when actually printing) and the white-paper sizing/scroll behavior. The
 * bill's own content (BillTemplate) is passed in as children so this stays
 * document-type-agnostic.
 */
export default function PrintPreviewModal({ title, onClose, children }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-3xl max-h-[90vh] overflow-y-auto rounded-2xl bg-[#ffffff] shadow-2xl print:max-h-none print:overflow-visible print:shadow-none print:rounded-none">
        <div className="flex items-center justify-between border-b p-4 print:hidden">
          <span className="font-bold text-gray-900">{title}</span>
          <div className="flex items-center gap-3">
            <button onClick={() => window.print()} className="rounded-lg bg-orange-500 px-4 py-2 text-sm text-white hover:bg-orange-600">
              <Printer size={14} className="mr-1 inline" /> Print
            </button>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-700"><X size={20} /></button>
          </div>
        </div>

        {/* A printed bill must always be pure white paper regardless of the
            app's own theme — plain bg-white would resolve through this app's
            --color-white token, which the light theme remaps to deep navy.
            The bracket value bypasses that token entirely. */}
        <div className="m-4 bg-[#ffffff] print:m-0">
          {children}
        </div>
      </div>
    </div>
  );
}
