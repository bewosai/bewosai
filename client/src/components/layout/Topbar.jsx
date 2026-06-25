import { Menu, Bell, Search, LogOut, ChevronDown, Building2 } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";

export default function Topbar({ onMenuClick }) {
  const navigate = useNavigate();
  const { user, currentBusiness, logout } = useAuth();

  async function handleLogout() {
    await logout();
    navigate("/login");
  }

  return (
    <header className="sticky top-0 z-30 border-b border-navy-800 bg-navy-950/90 backdrop-blur">
      <div className="flex items-center justify-between gap-4 px-4 py-3 sm:px-6">
        {/* Left */}
        <div className="flex items-center gap-3">
          <button
            onClick={onMenuClick}
            className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 hover:text-white lg:hidden"
          >
            <Menu className="h-5 w-5" />
          </button>

          <div className="hidden items-center gap-2 rounded-xl border border-navy-800 bg-navy-900 px-3 py-2 md:flex">
            <Search className="h-4 w-4 text-navy-500" />
            <input
              type="text"
              placeholder="Search invoice, product, party…"
              className="w-64 bg-transparent text-sm text-white outline-none placeholder:text-navy-500"
            />
          </div>
        </div>

        {/* Right */}
        <div className="flex items-center gap-2">
          {/* Business switcher */}
          <button
            onClick={() => navigate("/select-business")}
            className="hidden items-center gap-2 rounded-xl border border-navy-800 bg-navy-900 px-3 py-2 transition hover:border-orange-500/50 sm:flex"
          >
            <Building2 className="h-4 w-4 text-orange-400" />
            <span className="max-w-30 truncate text-sm text-white">
              {currentBusiness?.name || "Select Business"}
            </span>
            <ChevronDown className="h-3 w-3 text-navy-500" />
          </button>

          <button className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 transition hover:text-orange-400">
            <Bell className="h-5 w-5" />
          </button>

          <div className="hidden rounded-xl border border-navy-800 bg-navy-900 px-3 py-2 sm:block">
            <p className="text-sm font-medium text-white">{user?.name || "User"}</p>
            <p className="text-[10px] text-navy-400">{currentBusiness?.plan || "Free"} Plan</p>
          </div>

          <button
            onClick={handleLogout}
            className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 transition hover:text-red-400"
          >
            <LogOut className="h-5 w-5" />
          </button>
        </div>
      </div>
    </header>
  );
}
