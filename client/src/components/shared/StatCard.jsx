export default function StatCard({ label, value, note }) {
  return (
    <div className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-lg shadow-black/20">
      <p className="text-sm text-slate-400">{label}</p>
      <h3 className="mt-2 text-2xl font-bold text-white">{value}</h3>
      {note ? <p className="mt-2 text-xs text-emerald-300">{note}</p> : null}
    </div>
  );
}