import { useEffect } from "react";

// Lets a modal close on Escape — used by every modal a keyboard shortcut
// can open (see useKeyboardShortcuts), so "opened by keyboard" always means
// "closable by keyboard" too, not just by clicking the X.
export function useEscToClose(onClose) {
  useEffect(() => {
    const handler = (e) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);
}
