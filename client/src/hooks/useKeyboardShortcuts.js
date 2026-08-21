import { useEffect } from "react";
import { useNavigate } from "react-router-dom";

// Full list lives in KeyboardShortcutsModal — keep the two in sync when
// changing anything here.
export const SHORTCUTS = {
  addData: [
    { keys: "Alt + I", label: "Payment In" },
    { keys: "Alt + O", label: "Payment Out" },
    { keys: "Alt + E", label: "Expense" },
    { keys: "Alt + N", label: "Party" },
  ],
  goTo: [
    { keys: "Shift + D", label: "Dashboard" },
    { keys: "Shift + P", label: "Parties" },
    { keys: "Shift + E", label: "Expense" },
    { keys: "Shift + Q", label: "Quick POS" },
    { keys: "Shift + S", label: "Settings" },
    { keys: "Shift + R", label: "Reports" },
    { keys: "Shift + H", label: "Help & Support" },
    { keys: "Shift + K", label: "Keyboard Shortcuts" },
    { keys: "Shift + M", label: "Toggle Sidebar" },
    { keys: "Esc", label: "Close Dialog" },
  ],
};

function isTypingTarget(el) {
  if (!el) return false;
  const tag = el.tagName;
  return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || el.isContentEditable;
}

/**
 * Global shortcut listener — mounted once in AppLayout. Alt+<letter> jumps
 * straight to adding a record; Shift+<letter> jumps to a page. Guarded
 * against firing while the user is typing, since Shift+<letter> is also
 * literally how a capital letter gets typed in any text field.
 */
export function useKeyboardShortcuts({ onToggleSidebar, onShowHelp, onShowShortcuts }) {
  const navigate = useNavigate();

  useEffect(() => {
    const handler = (e) => {
      if (isTypingTarget(document.activeElement)) return;
      if (e.ctrlKey || e.metaKey) return; // leave browser/OS combos alone

      if (e.altKey && !e.shiftKey) {
        switch (e.code) {
          case "KeyI": e.preventDefault(); navigate("/payments?action=in"); return;
          case "KeyO": e.preventDefault(); navigate("/payments?action=out"); return;
          case "KeyE": e.preventDefault(); navigate("/expenses?action=add"); return;
          case "KeyN": e.preventDefault(); navigate("/parties?action=add"); return;
          default: return;
        }
      }

      if (e.shiftKey && !e.altKey) {
        switch (e.code) {
          case "KeyD": e.preventDefault(); navigate("/dashboard"); return;
          case "KeyP": e.preventDefault(); navigate("/parties"); return;
          case "KeyE": e.preventDefault(); navigate("/expenses"); return;
          case "KeyQ": e.preventDefault(); navigate("/sales?action=new"); return;
          case "KeyS": e.preventDefault(); navigate("/settings"); return;
          case "KeyR": e.preventDefault(); navigate("/reports"); return;
          case "KeyH": e.preventDefault(); onShowHelp(); return;
          case "KeyK": e.preventDefault(); onShowShortcuts(); return;
          case "KeyM": e.preventDefault(); onToggleSidebar(); return;
          default: return;
        }
      }
    };

    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [navigate, onToggleSidebar, onShowHelp, onShowShortcuts]);
}
