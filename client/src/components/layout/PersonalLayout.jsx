import { useState } from "react";
import { Outlet, NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import bewosaiLogo from "../../assessts/images/bewosai.png";
import {
  LayoutDashboard, TrendingDown, TrendingUp, BarChart3,
  Settings, LogOut, Menu, X, Bell, User,
} from "lucide-react";

const personalNav = [
  { name: "Dashboard",  path: "/personal/dashboard", icon: LayoutDashboard },
  { name: "Expenses",   path: "/personal/expenses",  icon: TrendingDown },
  { name: "Reports",    path: "/personal/reports",   icon: BarChart3 },
  { name: "Settings",   path: "/personal/settings",  icon: Settings },
];

function PersonalSidebar({ open, setOpen }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => { await logout(); navigate("/login"); };

  return (
    <>
      {open && <div className="fixed inset-0 z-40 bg-black/60 lg:hidden" onClick={() => setOpen(false)} />}

      <aside className={`fixed inset-y-0 left-0 z-50 flex w-60 flex-col border-r border-navy-800 bg-navy-950 transition-transform duration-300 lg:static lg:translate-x-0 ${open ? "translate-x-0" : "-translate-x-full"}`}>
        {/* Logo */}
        <div className="flex items-center justify-between border-b border-navy-800 px-4 py-4">
          <div className="flex items-center gap-2.5">
            <img src={bewosaiLogo} alt="Bewosai" className="h-8 w-8 rounded-xl object-cover" />
            <div>
              <p className="text-sm font-bold text-white">Bewosai</p>
              <p className="text-[10px] text-navy-400">Personal Finance</p>
            </div>
          </div>
          <button onClick={() => setOpen(false)} className="text-navy-400 hover:text-white lg:hidden">
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* User badge */}
        <div className="mx-3 my-3 flex items-center gap-2.5 rounded-xl border border-navy-800 bg-navy-900 px-3 py-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-blue-500/15 text-sm font-bold text-blue-400">
            {user?.name?.[0]?.toUpperCase() || "P"}
          </div>
          <div className="min-w-0">
            <p className="truncate text-xs font-semibold text-white">{user?.name || user?.email}</p>
            <p className="text-[10px] text-navy-400">Personal Account</p>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 pb-4">
          <p className="mb-2 px-1 text-[10px] font-semibold uppercase tracking-widest text-navy-500">Menu</p>
          <div className="space-y-0.5">
            {personalNav.map(({ name, path, icon: Icon }) => (
              <NavLink key={name} to={path} onClick={() => setOpen(false)}
                className={({ isActive }) => `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${isActive ? "bg-orange-500/15 text-orange-400 border border-orange-500/20" : "text-navy-200 hover:bg-navy-800 hover:text-white"}`}>
                <Icon className="h-4 w-4" /> {name}
              </NavLink>
            ))}
          </div>
        </nav>

        {/* Logout */}
        <div className="border-t border-navy-800 p-3">
          <button onClick={handleLogout}
            className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-navy-400 transition hover:bg-red-500/10 hover:text-red-400">
            <LogOut className="h-4 w-4" /> Sign Out
          </button>
        </div>
      </aside>
    </>
  );
}

export default function PersonalLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="flex min-h-screen bg-navy-950 text-white">
      <PersonalSidebar open={sidebarOpen} setOpen={setSidebarOpen} />

      <div className="flex min-h-screen flex-1 flex-col overflow-hidden">
        {/* Topbar */}
        <header className="sticky top-0 z-30 border-b border-navy-800 bg-navy-950/90 backdrop-blur">
          <div className="flex items-center justify-between px-4 py-3 sm:px-6">
            <button onClick={() => setSidebarOpen(true)} className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 lg:hidden">
              <Menu className="h-5 w-5" />
            </button>

            <div className="flex items-center gap-2 ml-auto">
              <button className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 hover:text-orange-400">
                <Bell className="h-5 w-5" />
              </button>
              <div className="rounded-xl border border-navy-800 bg-navy-900 px-3 py-2">
                <p className="text-sm font-medium text-white">{user?.name || "Personal"}</p>
                <p className="text-[10px] text-navy-400">Personal Account</p>
              </div>
              <button onClick={async () => { await logout(); navigate("/login"); }}
                className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 hover:text-red-400">
                <LogOut className="h-5 w-5" />
              </button>
            </div>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-4 sm:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
