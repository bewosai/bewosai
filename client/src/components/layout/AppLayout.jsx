import { useState } from "react";
import { Outlet } from "react-router-dom";
import Sidebar from "./Sidebar";
import Topbar from "./Topbar";
import TrialBanner from "./TrialBanner";
import KeyboardShortcutsModal from "../common/KeyboardShortcutsModal";
import HelpSupportModal from "../common/HelpSupportModal";
import { useKeyboardShortcuts } from "../../hooks/useKeyboardShortcuts";

export default function AppLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [showShortcuts, setShowShortcuts] = useState(false);
  const [showHelp, setShowHelp] = useState(false);

  useKeyboardShortcuts({
    onToggleSidebar: () => setSidebarOpen((o) => !o),
    onShowHelp: () => setShowHelp(true),
    onShowShortcuts: () => setShowShortcuts(true),
  });

  return (
    <div className="flex h-screen overflow-hidden bg-navy-950 text-white">
      <Sidebar open={sidebarOpen} setOpen={setSidebarOpen} />

      {/* Main column */}
      <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
        <Topbar onMenuClick={() => setSidebarOpen(true)} />
        <TrialBanner />

        {/* Scrollable content */}
        <main className="flex-1 overflow-y-auto">
          <div className="mx-auto max-w-7xl px-3 py-4 sm:px-5 sm:py-6">
            <Outlet />
          </div>
        </main>
      </div>

      {showShortcuts && <KeyboardShortcutsModal onClose={() => setShowShortcuts(false)} />}
      {showHelp && (
        <HelpSupportModal
          onClose={() => setShowHelp(false)}
          onShowShortcuts={() => { setShowHelp(false); setShowShortcuts(true); }}
        />
      )}
    </div>
  );
}
