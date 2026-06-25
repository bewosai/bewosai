export default function StatCard({ label, value, note, accent = false }) {
  return (
    <div className={`rounded-2xl border p-5 transition ${
      accent
        ? "border-orange-500/30 bg-orange-500/5"
        : "border-navy-800 bg-navy-900"
    }`}>
      <p className="text-xs font-medium uppercase tracking-wider text-navy-400">{label}</p>
      <h3 className="mt-2 text-2xl font-extrabold text-white">{value}</h3>
      {note && <p className="mt-1.5 text-xs text-orange-400">{note}</p>}
    </div>
  );
}
