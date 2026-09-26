import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from "recharts";

// Split out of Dashboard.jsx and lazy-loaded there: the chart library is the
// largest thing the dashboard needs, and the figures above it shouldn't wait
// for it to download.

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-navy-800 bg-navy-900 p-3 shadow-xl">
      <p className="text-xs font-semibold text-white mb-2">{label}</p>
      {payload.map((p) => (
        <p key={p.name} className="text-xs" style={{ color: p.color }}>
          {p.name}: Rs. {Number(p.value).toLocaleString("en-IN", { maximumFractionDigits: 0 })}
        </p>
      ))}
    </div>
  );
};

export default function MonthlyChart({ data, labels }) {
  return (
    <ResponsiveContainer width="100%" height={260}>
      <BarChart data={data} margin={{ top: 0, right: 10, left: -10, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="var(--color-navy-800)" />
        <XAxis dataKey="name" tick={{ fill: "var(--color-navy-500)", fontSize: 11 }} axisLine={false} tickLine={false} />
        <YAxis tick={{ fill: "var(--color-navy-500)", fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={(v) => `${(v/1000).toFixed(0)}k`} />
        <Tooltip content={<CustomTooltip />} />
        <Legend wrapperStyle={{ fontSize: "12px", color: "var(--color-navy-400)" }} />
        <Bar dataKey={labels.revenue} fill="#3b82f6" radius={[4, 4, 0, 0]} maxBarSize={30} />
        <Bar dataKey={labels.expenses} fill="#ef4444" radius={[4, 4, 0, 0]} maxBarSize={30} />
        <Bar dataKey={labels.profit} fill="#f59e0b" radius={[4, 4, 0, 0]} maxBarSize={30} />
      </BarChart>
    </ResponsiveContainer>
  );
}
