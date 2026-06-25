import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import PageHeader from "../components/shared/PageHeader";
import StatCard from "../components/shared/StatCard";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { reports as reportsApi } from "../api";
import {
  TrendingUp, TrendingDown, AlertTriangle, DollarSign,
  ShoppingCart, Package, Plus,
} from "lucide-react";

export default function DashboardPage() {
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    reportsApi.dashboard()
      .then((r) => setData(r.data))
      .catch(() => setData(null))
      .finally(() => setLoading(false));
  }, []);

  const stats = data
    ? [
        { label: "Sales Today",    value: `Rs. ${Number(data.sales_today).toLocaleString()}`,     note: "Today's confirmed sales" },
        { label: "Sales This Month", value: `Rs. ${Number(data.sales_month).toLocaleString()}`,   note: "+vs last month" },
        { label: "Receivable",     value: `Rs. ${Number(data.total_receivable).toLocaleString()}`, note: "Pending dues" },
        { label: "Expenses (Month)", value: `Rs. ${Number(data.expenses_month).toLocaleString()}`, note: "Total outflow" },
      ]
    : [
        { label: "Sales Today",      value: "–" },
        { label: "Sales This Month", value: "–" },
        { label: "Receivable",       value: "–" },
        { label: "Expenses",         value: "–" },
      ];

  return (
    <div>
      <PageHeader
        title="Dashboard"
        subtitle="Overview of your business performance today."
        action={
          <PrimaryButton onClick={() => navigate("/sales/invoice")}>
            <Plus className="h-4 w-4" /> New Sale
          </PrimaryButton>
        }
      />

      {/* Stats */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((s) => (
          <StatCard key={s.label} {...s} />
        ))}
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-3">
        {/* Quick summary */}
        <SectionCard title="Quick Summary">
          {loading ? (
            <p className="text-sm text-navy-400">Loading…</p>
          ) : (
            <div className="space-y-3 text-sm">
              {[
                { label: "Net Profit (Month)", value: `Rs. ${Number(data?.profit_month || 0).toLocaleString()}`, color: "text-orange-400" },
                { label: "Low Stock Items",    value: data?.low_stock_count ?? "–",                             color: "text-red-400" },
                { label: "Sales This Month",   value: `Rs. ${Number(data?.sales_month || 0).toLocaleString()}`, color: "text-white" },
                { label: "Expenses (Month)",   value: `Rs. ${Number(data?.expenses_month || 0).toLocaleString()}`, color: "text-white" },
              ].map(({ label, value, color }) => (
                <div key={label} className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-2.5">
                  <span className="text-navy-400">{label}</span>
                  <span className={`font-semibold ${color}`}>{value}</span>
                </div>
              ))}
            </div>
          )}
        </SectionCard>

        {/* Recent sales */}
        <div className="xl:col-span-2">
          <SectionCard
            title="Recent Sales"
            action={
              <button
                onClick={() => navigate("/sales")}
                className="text-xs text-orange-400 hover:text-orange-300"
              >
                View all →
              </button>
            }
          >
            {loading ? (
              <p className="text-sm text-navy-400">Loading…</p>
            ) : data?.recent_sales?.length ? (
              <div className="space-y-2">
                {data.recent_sales.map((sale) => (
                  <div
                    key={sale.id}
                    className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3"
                  >
                    <div>
                      <p className="text-sm font-medium text-white">{sale.invoice_number}</p>
                      <p className="text-xs text-navy-400">
                        {sale.customer_name || "Walk-in"} · {sale.sale_date}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-semibold text-white">
                        Rs. {Number(sale.total).toLocaleString()}
                      </p>
                      <span className={`text-xs font-medium ${
                        sale.status === "CONFIRMED" ? "text-orange-400" : "text-navy-500"
                      }`}>
                        {sale.status}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center gap-3 py-8 text-center">
                <ShoppingCart className="h-10 w-10 text-navy-700" />
                <p className="text-sm text-navy-400">No sales yet. Create your first sale.</p>
                <PrimaryButton onClick={() => navigate("/sales/invoice")}>
                  <Plus className="h-4 w-4" /> New Sale
                </PrimaryButton>
              </div>
            )}
          </SectionCard>
        </div>
      </div>

      {/* Low stock + quick actions */}
      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <SectionCard
          title="Low Stock Alerts"
          action={
            <button onClick={() => navigate("/inventory/low-stock")} className="text-xs text-orange-400 hover:text-orange-300">
              View all →
            </button>
          }
        >
          {loading ? (
            <p className="text-sm text-navy-400">Loading…</p>
          ) : (data?.low_stock_count || 0) > 0 ? (
            <div className="flex items-center gap-4 rounded-xl border border-red-500/20 bg-red-500/5 p-4">
              <AlertTriangle className="h-8 w-8 shrink-0 text-red-400" />
              <div>
                <p className="font-semibold text-white">{data.low_stock_count} items running low</p>
                <p className="text-sm text-navy-400">Check inventory to restock.</p>
              </div>
            </div>
          ) : (
            <div className="flex items-center gap-3 text-sm text-navy-400">
              <Package className="h-5 w-5 text-orange-400" />
              All stock levels are healthy.
            </div>
          )}
        </SectionCard>

        <SectionCard title="Quick Actions">
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "New Sale",      path: "/sales/invoice",      icon: ShoppingCart },
              { label: "Add Expense",   path: "/expenses",            icon: TrendingDown },
              { label: "Add Product",   path: "/inventory/products",  icon: Package },
              { label: "Add Party",     path: "/parties",             icon: DollarSign },
            ].map(({ label, path, icon: Icon }) => (
              <button
                key={label}
                onClick={() => navigate(path)}
                className="flex items-center gap-2 rounded-xl border border-navy-800 bg-navy-950 px-3 py-3 text-sm font-medium text-navy-200 transition hover:border-orange-500/50 hover:text-white"
              >
                <Icon className="h-4 w-4 text-orange-400" />
                {label}
              </button>
            ))}
          </div>
        </SectionCard>
      </div>
    </div>
  );
}
