import { Menu, Bell, Search, LogOut } from "lucide-react";
import { useNavigate } from "react-router-dom";

export default function Topbar({ onMenuClick }) {
  const navigate = useNavigate();

  function handleLogout() {
    localStorage.removeItem("accessToken");
    navigate("/login");
  }

  return (
    <header className="sticky top-0 z-30 border-b border-slate-800 bg-slate-950/80 backdrop-blur">
      <div className="flex items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <div className="flex items-center gap-3">
          <button
            onClick={onMenuClick}
            className="rounded-xl border border-slate-800 bg-slate-900 p-2 text-slate-300 lg:hidden"
          >
            <Menu className="h-5 w-5" />
          </button>

          <div className="hidden items-center gap-2 rounded-2xl border border-slate-800 bg-slate-900 px-4 py-2 md:flex">
            <Search className="h-4 w-4 text-slate-500" />
            <input
              type="text"
              placeholder="Search invoice, item, party..."
              className="w-72 bg-transparent text-sm text-white outline-none placeholder:text-slate-500"
            />
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button className="rounded-xl border border-slate-800 bg-slate-900 p-2 text-slate-300 hover:text-emerald-300">
            <Bell className="h-5 w-5" />
          </button>

          <div className="hidden rounded-2xl border border-slate-800 bg-slate-900 px-4 py-2 sm:block">
            <p className="text-sm font-medium text-white">Rajan</p>
            <p className="text-xs text-slate-400">Business Owner</p>
          </div>

          <button
            onClick={handleLogout}
            className="rounded-xl border border-slate-800 bg-slate-900 p-2 text-slate-300 hover:text-red-400"
          >
            <LogOut className="h-5 w-5" />
          </button>
        </div>
      </div>
    </header>
  );
}