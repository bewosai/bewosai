import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";

export default function PurchasesPage() {
  return (
    <div>
      <PageHeader
        title="Purchases"
        subtitle="Manage supplier bills, incoming stock, and due payments."
        action={<PrimaryButton>+ New Purchase</PrimaryButton>}
      />

      <SectionCard title="Purchase Bills">
        <div className="flex h-72 items-center justify-center rounded-2xl border border-dashed border-emerald-500/30 bg-slate-950/60 text-slate-400">
          Purchases list and bill form UI here
        </div>
      </SectionCard>
    </div>
  );
}