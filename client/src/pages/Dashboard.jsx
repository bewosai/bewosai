import PageHeader from "../components/shared/PageHeader";
import StatCard from "../components/shared/StatCard";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";

export default function DashboardPage() {
  const stats = [
    { label: "Total Sales", value: "Rs. 245,000", note: "+12% this month" },
    { label: "Purchases", value: "Rs. 140,000", note: "Stock refill active" },
    { label: "Receivable", value: "Rs. 52,500", note: "7 pending dues" },
    { label: "Expenses", value: "Rs. 18,900", note: "Operational costs" },
  ];

  return (
    <div>
      <PageHeader
        title="Dashboard"
        subtitle="Overview of your business performance, dues, stock, and activity."
        action={<PrimaryButton>+ New Sale</PrimaryButton>}
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {stats.map((item) => (
          <StatCard key={item.label} {...item} />
        ))}
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <SectionCard title="Sales Trend">
            <div className="flex h-72 items-center justify-center rounded-2xl border border-dashed border-emerald-500/30 bg-slate-950/60 text-slate-400">
              Monthly sales chart goes here
            </div>
          </SectionCard>
        </div>

        <SectionCard title="Quick Summary">
          <div className="space-y-4 text-sm">
            <div className="flex justify-between text-slate-300">
              <span>Cash In</span>
              <span className="font-semibold text-white">Rs. 90,000</span>
            </div>
            <div className="flex justify-between text-slate-300">
              <span>Cash Out</span>
              <span className="font-semibold text-white">Rs. 35,000</span>
            </div>
            <div className="flex justify-between text-slate-300">
              <span>Net Profit</span>
              <span className="font-semibold text-emerald-300">Rs. 86,100</span>
            </div>
            <div className="flex justify-between text-slate-300">
              <span>Low Stock Items</span>
              <span className="font-semibold text-amber-300">5</span>
            </div>
          </div>
        </SectionCard>
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <SectionCard title="Recent Sales">
          <div className="space-y-3">
            {["INV-001", "INV-002", "INV-003"].map((sale) => (
              <div
                key={sale}
                className="flex items-center justify-between rounded-2xl border border-slate-800 bg-slate-950/60 p-4"
              >
                <div>
                  <p className="font-medium text-white">{sale}</p>
                  <p className="text-sm text-slate-400">Customer invoice</p>
                </div>
                <p className="font-semibold text-emerald-300">Rs. 12,500</p>
              </div>
            ))}
          </div>
        </SectionCard>

        <SectionCard title="Low Stock Alerts">
          <div className="space-y-3">
            {["Rice Bag 25kg", "Oil 1L", "Sugar 5kg"].map((item) => (
              <div
                key={item}
                className="flex items-center justify-between rounded-2xl border border-slate-800 bg-slate-950/60 p-4"
              >
                <div>
                  <p className="font-medium text-white">{item}</p>
                  <p className="text-sm text-slate-400">Reorder soon</p>
                </div>
                <p className="font-semibold text-amber-300">2 left</p>
              </div>
            ))}
          </div>
        </SectionCard>
      </div>
    </div>
  );
}