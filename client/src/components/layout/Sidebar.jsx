import { NavLink } from "react-router-dom";
import { useState, useEffect } from "react";
import { useAuth } from "../../context/AuthContext";
import { useFeatures } from "../../context/FeatureContext";
import { useTranslation } from "../../utils/translations";
import { useOfflineSync } from "../../utils/offlineQueue";
import api from "../../api/index";
import bewosaiLogo from "@assets/images/bewosai.png";
import {
  LayoutDashboard, Users, Package, ShoppingCart, Truck,
  Wallet, Receipt, BarChart3, X, Building2, ChevronDown,
  Boxes, CreditCard, UserCheck, ShieldCheck, Settings,
  Trash2, FileText, ArrowLeftRight, FileSpreadsheet,
  Wifi, WifiOff, RefreshCw,
} from "lucide-react";

const PLAN_LABELS = { FREE: "Free", PREMIUM: "Premium", PREMIUMPLUS: "Premium Plus" };

function buildNavItems(t, language) {
  return [
    { name: t("dashboard"), path: "/dashboard", icon: LayoutDashboard },
    {
      name: t("sales"),
      icon: ShoppingCart,
      feature: "pos",
      children: [
        { name: t("allInvoices"), path: "/sales" },
        { name: t("quotation"), path: "/sales/quotation" },
        { name: t("salesReturn"), path: "/sales/return" },
      ],
    },
    {
      name: t("purchases"),
      icon: Truck,
      feature: "purchases",
      children: [
        { name: t("allPurchases"), path: "/purchases" },
        { name: t("paymentOut"), path: "/payments?action=out" },
        { name: t("purchaseReturn"), path: "/purchases/return" },
      ],
    },
    { name: t("expenses"), path: "/expenses", icon: Receipt, feature: "expenses" },
    {
      name: t("inventory"),
      icon: Boxes,
      feature: "inventory",
      children: [
        { name: t("products"), path: "/inventory/products" },
        { name: t("categories"), path: "/inventory/categories" },
        { name: t("units"), path: "/inventory" },
        { name: t("lowStock"), path: "/inventory/low-stock" },
      ],
    },
    { name: t("parties"), path: "/parties", icon: Users, feature: "parties" },
    { name: t("payments"), path: "/payments", icon: Wallet, feature: "payments" },
    {
      name: t("banking"),
      icon: CreditCard,
      feature: "banking",
      children: [
        { name: t("banking"), path: "/banking/accounts" },
        { name: t("report"), path: "/banking/transactions" },
      ],
    },
    { name: t("staff"), path: "/staff", icon: UserCheck, feature: "staff_management" },
    { name: t("reports"), path: "/reports", icon: BarChart3, feature: "reports" },
    { name: t("settings"), path: "/settings", icon: Settings },
    { name: t("recycleBin"), path: "/recycle-bin", icon: Trash2 },
    { name: language === "ne" ? "Excel आयात" : "Import Excel", path: "/import", icon: FileSpreadsheet, feature: "excel_import" },
  ];
}

function NavItem({ item, onClose }) {
  const Icon = item.icon;
  const [open, setOpen] = useState(false);

  if (item.children) {
    return (
      <div>
        <button
          onClick={() => setOpen(!open)}
          className="flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-sm font-medium text-navy-300 transition hover:bg-navy-800 hover:text-white"
        >
          <div className="flex items-center gap-3">
            <Icon className="h-4 w-4 text-navy-500" />
            {item.name}
          </div>
          <ChevronDown className={`h-3.5 w-3.5 text-navy-500 transition-transform duration-200 ${open ? "rotate-180" : ""}`} />
        </button>
        {open && (
          <div className="ml-7 mt-1 space-y-0.5 border-l border-navy-800 pl-3">
            {item.children.map((child) => (
              <NavLink
                key={child.path}
                to={child.path}
                onClick={onClose}
                className={({ isActive }) =>
                  `block rounded-lg px-3 py-2 text-sm transition ${
                    isActive
                      ? "bg-orange-500/15 font-semibold text-orange-500"
                      : "text-navy-400 hover:bg-navy-800 hover:text-white"
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

  return (
    <NavLink
      to={item.path}
      onClick={onClose}
      className={({ isActive }) =>
        `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
          isActive
            ? "bg-orange-500/15 text-orange-500 border border-orange-500/20"
            : "text-navy-300 hover:bg-navy-800 hover:text-white"
        }`
      }
    >
      <Icon className="h-4 w-4" />
      {item.name}
    </NavLink>
  );
}

export default function Sidebar({ open, setOpen }) {
  const { currentBusiness, user } = useAuth();
  const { t, language } = useTranslation();
  const { isFeatureEnabled } = useFeatures();
  const { isOnline, pendingCount, isSyncing, flush } = useOfflineSync(api);
  const navItems = buildNavItems(t, language)
    .filter((item) => !item.feature || isFeatureEnabled(item.feature));

  return (
    <>
      {open && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setOpen(false)}
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-50 flex w-64 flex-col border-r border-navy-800 bg-navy-900 transition-transform duration-300 lg:static lg:translate-x-0 ${
          open ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        {/* Logo */}
        <div className="flex items-center justify-between border-b border-navy-800 px-4 py-4">
          {/* The logo is the Home button: one click from any page back to the dashboard. */}
          <NavLink to="/dashboard" onClick={() => setOpen(false)} title="Home" className="flex items-center gap-3">
            <img src={bewosaiLogo} alt="Bewosai" className="h-9 w-9 rounded-xl object-cover ring-2 ring-orange-500/30" />
            <div>
              <h1 className="text-base font-bold text-white">Bewosai</h1>
              <p className="text-[10px] text-navy-500">Business Suite</p>
            </div>
          </NavLink>
          <button
            onClick={() => setOpen(false)}
            className="rounded-lg p-1.5 text-navy-400 hover:bg-navy-800 hover:text-white lg:hidden"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Business badge */}
        <div className="mx-3 my-3 rounded-xl border border-orange-500/20 bg-orange-500/5 px-3 py-2.5">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-orange-500/20">
              <Building2 className="h-4 w-4 text-orange-500" />
            </div>
            <div className="min-w-0">
              <p className="truncate text-xs font-semibold text-white">
                {currentBusiness?.name || "My Business"}
              </p>
              <p className="text-[10px] text-navy-500">
                {PLAN_LABELS[currentBusiness?.effective_plan || currentBusiness?.plan] || "Free"} Plan
              </p>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 overflow-y-auto px-3 pb-4">
          <p className="mb-2 px-1 text-[10px] font-semibold uppercase tracking-widest text-navy-500">
            Menu
          </p>
          <div className="space-y-0.5">
            {navItems.map((item) => (
              <NavItem key={item.name} item={item} onClose={() => setOpen(false)} />
            ))}
          </div>

          {user?.is_platform_admin && (
            <>
              <p className="mb-2 mt-5 px-1 text-[10px] font-semibold uppercase tracking-widest text-navy-500">
                Platform
              </p>
              <NavLink
                to="/superadmin"
                onClick={() => setOpen(false)}
                className={({ isActive }) =>
                  `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                    isActive
                      ? "bg-orange-500/15 text-orange-500 border border-orange-500/20"
                      : "text-navy-300 hover:bg-navy-800 hover:text-white"
                  }`
                }
              >
                <ShieldCheck className="h-4 w-4" /> Super Admin
              </NavLink>
            </>
          )}
        </nav>

        {/* Offline indicator */}
        {!isOnline && (
          <div className="mx-3 mb-2 flex items-center gap-2 rounded-xl border border-red-500/30 bg-red-500/10 px-3 py-2">
            <WifiOff className="h-3.5 w-3.5 shrink-0 text-red-400" />
            <div className="min-w-0 flex-1">
              <p className="text-xs font-semibold text-red-400">Offline</p>
              {pendingCount > 0 && (
                <p className="text-[10px] text-navy-400">{pendingCount} action{pendingCount > 1 ? "s" : ""} queued</p>
              )}
            </div>
          </div>
        )}
        {isOnline && pendingCount > 0 && (
          <div className="mx-3 mb-2 flex items-center gap-2 rounded-xl border border-orange-500/30 bg-orange-500/10 px-3 py-2">
            {isSyncing ? (
              <RefreshCw className="h-3.5 w-3.5 shrink-0 animate-spin text-orange-400" />
            ) : (
              <Wifi className="h-3.5 w-3.5 shrink-0 text-orange-400" />
            )}
            <div className="min-w-0 flex-1">
              <p className="text-xs font-semibold text-orange-400">
                {isSyncing ? "Syncing…" : `${pendingCount} pending`}
              </p>
              {!isSyncing && (
                <button onClick={flush} className="text-[10px] text-navy-400 hover:text-orange-300 underline">
                  Sync now
                </button>
              )}
            </div>
          </div>
        )}

        {/* Footer */}
        <div className="border-t border-navy-800 px-3 py-3">
          <div className="flex items-center gap-2 rounded-xl bg-orange-500/10 px-3 py-2.5">
            <div className={`h-2 w-2 shrink-0 rounded-full ${isOnline ? "bg-green-500" : "bg-red-500"}`} />
            <div className="min-w-0">
              <p className="text-xs font-bold text-orange-500">Bewosai</p>
              <p className="text-[10px] text-navy-500">
                {isOnline ? "Online · " : "Offline · "}Sales · Reports
              </p>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}
