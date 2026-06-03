export default function SectionCard({ title, children, right }) {
  return (
    <div className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-lg shadow-black/20">
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-lg font-semibold text-white">{title}</h2>
        {right}
      </div>
      {children}
    </div>
  );
}