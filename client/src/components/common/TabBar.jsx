/**
 * Horizontal tab bar.
 * tabs: [{ key, label, count? }]
 */
export default function TabBar({ tabs, active, onChange }) {
  return (
    <div className="flex flex-wrap gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1">
      {tabs.map(tab => (
        <button
          key={tab.key}
          onClick={() => onChange(tab.key)}
          className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
            active === tab.key ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"
          }`}
        >
          {tab.label}
          {tab.count != null && (
            <span
              className={`inline-flex h-4 min-w-4 items-center justify-center rounded-full px-1 text-[10px] font-bold ${
                active === tab.key ? "bg-white/20 text-white" : "bg-navy-700 text-navy-300"
              }`}
            >
              {tab.count}
            </span>
          )}
        </button>
      ))}
    </div>
  );
}
