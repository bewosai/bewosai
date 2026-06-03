import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";

export default function ReportsPage() {
  return (
    <div>
      <PageHeader
        title="Reports"
        subtitle="Analyze sales, purchases, stock, profit/loss, and ledgers."
        action={<PrimaryButton>Export</PrimaryButton>}
      />

      <div className="grid gap-6 lg:grid-cols-2">
        <SectionCard title="Sales Report">
          <div className="flex h-48 items-center justify-center rounded-2xl border border-dashed border-emerald-500/30 bg-slate-950/60 text-slate-400">
            Sales report summary
          </div>
        </SectionCard>

        <SectionCard title="Profit & Loss">
          <div className="flex h-48 items-center justify-center rounded-2xl border border-dashed border-emerald-500/30 bg-slate-950/60 text-slate-400">
            P&L summary
          </div>
        </SectionCard>

        <SectionCard title="Receivable Aging">
          <div className="flex h-48 items-center justify-center rounded-2xl border border-dashed border-emerald-500/30 bg-slate-950/60 text-slate-400">
            Aging report
          </div>
        </SectionCard>

        <SectionCard title="Stock Summary">
          <div className="flex h-48 items-center justify-center rounded-2xl border border-dashed border-emerald-500/30 bg-slate-950/60 text-slate-400">
            Stock summary report
          </div>
        </SectionCard>
      </div>
    </div>
  );
}