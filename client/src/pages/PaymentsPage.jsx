import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";

export default function PaymentsPage() {
  return (
    <div>
      <PageHeader
        title="Payments"
        subtitle="Track money received, supplier payments, and invoice settlements."
        action={<PrimaryButton>+ Add Payment</PrimaryButton>}
      />

      <SectionCard title="Payment Records">
        <div className="flex h-72 items-center justify-center rounded-2xl border border-dashed border-emerald-500/30 bg-slate-950/60 text-slate-400">
          Payments table and settlement UI here
        </div>
      </SectionCard>
    </div>
  );
}