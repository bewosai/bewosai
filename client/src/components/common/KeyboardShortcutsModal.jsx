import { Keyboard } from "lucide-react";
import Modal from "./Modal";
import { SHORTCUTS } from "../../hooks/useKeyboardShortcuts";

function ShortcutRow({ label, keys }) {
  return (
    <div className="flex items-center justify-between py-2">
      <span className="text-sm text-navy-200">{label}</span>
      <kbd className="rounded-lg border border-navy-700 bg-navy-800 px-2.5 py-1 text-xs font-semibold text-navy-300">
        {keys}
      </kbd>
    </div>
  );
}

export default function KeyboardShortcutsModal({ onClose }) {
  return (
    <Modal title="Keyboard Shortcuts" onClose={onClose} size="sm">
      <div className="space-y-5">
        <div>
          <div className="mb-1 flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-navy-500">
            <Keyboard className="h-3.5 w-3.5" /> For Adding Data
          </div>
          <div className="divide-y divide-navy-800">
            {SHORTCUTS.addData.map((s) => (
              <ShortcutRow key={s.keys} label={s.label} keys={s.keys} />
            ))}
          </div>
        </div>
        <div>
          <div className="mb-1 flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-navy-500">
            <Keyboard className="h-3.5 w-3.5" /> For Going to Pages
          </div>
          <div className="divide-y divide-navy-800">
            {SHORTCUTS.goTo.map((s) => (
              <ShortcutRow key={s.keys} label={s.label} keys={s.keys} />
            ))}
          </div>
        </div>
      </div>
    </Modal>
  );
}
