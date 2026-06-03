import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";

export default function ExpensesPage() {
  return (
    <div>
      <PageHeader
        title="Expenses"
        subtitle="Record business spending with categories and payment modes."
        action={<PrimaryButton>+ Add Expense</PrimaryButton>}
      />

      <SectionCard title="Expense Records">
        <div className="flex h-72 items-center justify-center rounded-2xl border border-dashed border-emerald-500/30 bg-slate-950/60 text-slate-400">
          Expenses list and analytics UI here
        </div>
      </SectionCard>
    </div>
  );
}