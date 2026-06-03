import { NavLink } from "react-router-dom";
import { useState } from "react";
import {
  LayoutDashboard,
  Users,
  Boxes,
  ShoppingCart,
  Truck,
  Wallet,
  Receipt,
  BarChart3,
  X,
  Building2,
  ChevronDown,
} from "lucide-react";

// ✅ FINAL NAV ITEMS (ONLY THIS)
const navItems = [
  { name: "Dashboard", path: "/dashboard", icon: LayoutDashboard },
  { name: "Parties", path: "/parties", icon: Users },
  { name: "Items", path: "/items", icon: Boxes },

  // ✅ SALES DROPDOWN
  {
    name: "Sales",
    icon: ShoppingCart,
    children: [
      { name: "New Sale", path: "/sales/new" },
      { name: "All Sales", path: "/sales" },
      { name: "Sales Return", path: "/sales/return" },
      { name: "Quotations", path: "/sales/quotation" },
    ],
  },

  { name: "Purchases", path: "/purchases", icon: Truck },
  { name: "Payments", path: "/payments", icon: Wallet },
  { name: "Expenses", path: "/expenses", icon: Receipt },
  { name: "Reports", path: "/reports", icon: BarChart3 },
];

function NavItem({ item, onClick }) {
  const Icon = item.icon;
  const [open, setOpen] = useState(false);

  // ✅ DROPDOWN ITEM (Sales)
  if (item.children) {
    return (
      <div>
        <button
          onClick={() => setOpen(!open)}
          className="flex w-full items-center justify-between rounded-2xl px-4 py-3 text-sm font-medium text-slate-300 hover:bg-slate-800"
        >
          <div className="flex items-center gap-3">
            <Icon className="h-5 w-5" />
            {item.name}
          </div>

          <ChevronDown
            className={`h-4 w-4 transition ${open ? "rotate-180" : ""}`}
          />
        </button>

        {open && (
          <div className="ml-10 mt-2 space-y-2">
            {item.children.map((child) => (
              <NavLink
                key={child.path}
                to={child.path}
                onClick={onClick}
                className={({ isActive }) =>
                  `block rounded-xl px-3 py-2 text-sm ${
                    isActive
                      ? "bg-emerald-500/15 text-emerald-300"
                      : "text-slate-400 hover:bg-slate-800"
                  }`
                }
              >
                {child.name}
              </NavLink>
            ))}
          </div>
        )}
      </div>
    );
  }

  // ✅ NORMAL ITEM
  return (
    <NavLink
      to={item.path}
      onClick={onClick}
      className={({ isActive }) =>
        `group flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-medium transition ${
          isActive
            ? "bg-emerald-500/15 text-emerald-300 border border-emerald-500/30"
            : "text-slate-300 hover:bg-slate-800 hover:text-emerald-200"
        }`
      }
    >
      <Icon className="h-5 w-5" />
      <span>{item.name}</span>
    </NavLink>
  );
}

export default function Sidebar({ open, setOpen }) {
  return (
    <>
      {/* Overlay */}
      {open && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 w-72 transform border-r border-slate-800 bg-slate-900/95 backdrop-blur transition-transform duration-300 lg:static lg:translate-x-0 ${
          open ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex h-full flex-col p-4">
          {/* LOGO */}
          <div className="mb-6 flex items-center justify-between rounded-2xl border border-emerald-500/20 bg-slate-950/70 p-4">
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-emerald-500/15 text-emerald-300">
                <Building2 className="h-6 w-6" />
              </div>
              <div>
                <h1 className="text-lg font-bold text-white">Bepar</h1>
                <p className="text-xs text-slate-400">Business Management</p>
              </div>
            </div>

            <button
              onClick={() => setOpen(false)}
              className="rounded-xl p-2 text-slate-400 hover:bg-slate-800 hover:text-white lg:hidden"
            >
              <X className="h-5 w-5" />
            </button>
          </div>

          {/* BUSINESS INFO */}
          <div className="mb-4 rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
            <p className="text-xs uppercase tracking-wider text-slate-500">
              Business
            </p>
            <h2 className="mt-1 font-semibold text-white">Rajan Traders</h2>
            <p className="mt-1 text-xs text-emerald-300">Owner Account</p>
          </div>

          {/* NAV */}
          <nav className="flex-1 space-y-2">
            {navItems.map((item) => (
              <NavItem
                key={item.name}
                item={item}
                onClick={() => setOpen(false)}
              />
            ))}
          </nav>

          {/* FOOTER */}
          <div className="mt-6 rounded-2xl border border-emerald-500/20 bg-emerald-500/10 p-4">
            <p className="text-sm font-semibold text-emerald-300">
              Trusted green theme
            </p>
            <p className="mt-1 text-xs text-slate-300">
              Manage sales, stock, parties, expenses, and reports from one place.
            </p>
          </div>
        </div>
      </aside>
    </>
  );
}