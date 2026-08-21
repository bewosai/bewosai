import { Keyboard, LifeBuoy } from "lucide-react";
import Modal from "./Modal";

function Tip({ title, children }) {
  return (
    <div className="rounded-xl border border-navy-800 bg-navy-950 p-3">
      <p className="text-sm font-semibold text-white">{title}</p>
      <p className="mt-0.5 text-xs text-navy-400">{children}</p>
    </div>
  );
}

export default function HelpSupportModal({ onClose, onShowShortcuts }) {
  return (
    <Modal title="Help & Support" onClose={onClose} size="sm">
      <div className="space-y-3">
        <div className="flex items-start gap-3 rounded-xl border border-orange-500/20 bg-orange-500/5 p-3">
          <LifeBuoy className="mt-0.5 h-4 w-4 shrink-0 text-orange-400" />
          <p className="text-xs text-navy-300">
            For account or billing issues, contact whoever set up this business for you —
            they can reach the platform team on your behalf.
          </p>
        </div>

        <Tip title="Work faster with the keyboard">
          Most pages and "add" actions have a shortcut — press <kbd className="rounded border border-navy-700 bg-navy-800 px-1">Shift + K</kbd> anytime to see them.
        </Tip>
        <Tip title="Offline entries sync automatically">
          If you lose connection, sales and other entries keep saving locally and sync once you're back online.
        </Tip>
        <Tip title="Recycle Bin">
          Deleted records aren't gone right away — they can be restored from Recycle Bin.
        </Tip>

        <button
          onClick={onShowShortcuts}
          className="flex w-full items-center justify-center gap-2 rounded-xl border border-navy-700 py-2.5 text-sm font-semibold text-navy-300 transition hover:bg-navy-800"
        >
          <Keyboard className="h-4 w-4" /> View Keyboard Shortcuts
        </button>
      </div>
    </Modal>
  );
}
