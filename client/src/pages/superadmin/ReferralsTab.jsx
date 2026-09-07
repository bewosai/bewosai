import { useState, useEffect, useCallback } from "react";
import { superadmin as adminApi } from "../../api";
import { Badge, PaginationFooter } from "../SuperAdminPage";
import { RefreshCw, Search, Loader, Trophy, Users2, CheckCircle2, XCircle } from "lucide-react";

const PAGE_SIZE = 50;
const STATUS_OPTIONS = ["REGISTERED", "VERIFIED", "REWARDED", "REJECTED", "EXPIRED"];
const STATUS_COLORS = { REGISTERED: "gray", VERIFIED: "blue", REWARDED: "green", REJECTED: "red", EXPIRED: "orange" };

function fmtDateTime(d) {
  if (!d) return "—";
  return new Date(d).toLocaleString(undefined, { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

function StatCard({ icon: Icon, label, value, color = "text-white" }) {
  return (
    <div className="rounded-xl border border-navy-800 bg-navy-900 px-4 py-3 flex items-center gap-3">
      <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-navy-800">
        <Icon className={`h-4 w-4 ${color}`} />
      </div>
      <div>
        <p className={`text-lg font-bold ${color}`}>{value ?? "—"}</p>
        <p className="text-xs text-navy-500">{label}</p>
      </div>
    </div>
  );
}

export default function ReferralsTab() {
  const [stats, setStats] = useState(null);
  const [rows, setRows] = useState([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({ status: "", search: "" });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, page_size: PAGE_SIZE };
      Object.entries(filters).forEach(([k, v]) => { if (v) params[k] = v; });
      const [list, statsRes] = await Promise.all([
        adminApi.referralList(params),
        adminApi.referralStats(),
      ]);
      setRows(list.data?.results ?? list.data ?? []);
      setCount(list.data?.count ?? (Array.isArray(list.data) ? list.data.length : 0));
      setStats(statsRes.data);
    } catch {
      setRows([]);
      setCount(0);
    } finally {
      setLoading(false);
    }
  }, [filters, page]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [filters]);

  return (
    <div className="space-y-4">
      <p className="text-xs text-navy-500">
        Refer & Earn activity — every business that's referred another, and whether the reward went through.
      </p>

      {/* Stats */}
      <div className="grid gap-3 sm:grid-cols-4">
        <StatCard icon={Users2} label="Total Referrals" value={stats?.total} />
        <StatCard icon={CheckCircle2} label="Verified" value={stats?.verified} color="text-blue-400" />
        <StatCard icon={Trophy} label="Rewarded" value={stats?.rewarded} color="text-green-400" />
        <StatCard icon={XCircle} label="Rejected" value={stats?.rejected} color="text-red-400" />
      </div>

      {stats?.top_referrers?.length > 0 && (
        <div className="rounded-xl border border-navy-800 bg-navy-900 p-4">
          <p className="mb-3 text-xs font-bold uppercase tracking-wide text-navy-500">Top Referrers</p>
          <div className="space-y-2">
            {stats.top_referrers.map((r, i) => (
              <div key={r.business_id} className="flex items-center justify-between text-sm">
                <span className="text-navy-300">{i + 1}. {r.business_name}</span>
                <span className="font-semibold text-white">{r.count}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="flex flex-wrap gap-2">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
          <input
            value={filters.search}
            onChange={(e) => setFilters((f) => ({ ...f, search: e.target.value }))}
            placeholder="Search business / owner…"
            className="w-56 rounded-lg border border-navy-700 bg-navy-900 py-2 pl-9 pr-3 text-xs text-white placeholder:text-navy-600 focus:border-orange-500 focus:outline-none"
          />
        </div>
        <select
          value={filters.status}
          onChange={(e) => setFilters((f) => ({ ...f, status: e.target.value }))}
          className="rounded-lg border border-navy-700 bg-navy-900 px-3 py-2 text-xs text-navy-300 focus:border-orange-500 focus:outline-none"
        >
          <option value="">All Statuses</option>
          {STATUS_OPTIONS.map((s) => <option key={s} value={s}>{s.charAt(0) + s.slice(1).toLowerCase()}</option>)}
        </select>
        <button onClick={load} className="flex items-center gap-1.5 rounded-lg border border-navy-700 px-3 py-2 text-xs text-navy-400 hover:bg-navy-800">
          <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} /> Refresh
        </button>
      </div>

      {/* Table */}
      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
        {loading ? (
          <div className="flex justify-center py-16"><Loader className="h-5 w-5 animate-spin text-orange-500" /></div>
        ) : rows.length === 0 ? (
          <p className="px-4 py-10 text-center text-sm text-navy-500">No referrals match these filters.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-navy-800 text-left text-xs text-navy-500">
                <th className="px-4 py-3 font-medium">Referrer</th>
                <th className="px-4 py-3 font-medium">New Business</th>
                <th className="px-4 py-3 font-medium">Registered</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium">Detail</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-navy-800/50">
              {rows.map((r) => (
                <tr key={r.id} className="hover:bg-navy-800/30 transition">
                  <td className="px-4 py-3 text-navy-300">
                    <p className="text-white">{r.referrer_business_name}</p>
                    <p className="text-xs text-navy-500">{r.referrer_owner_email}</p>
                  </td>
                  <td className="px-4 py-3 text-navy-300">
                    <p className="text-white">{r.referred_business_name}</p>
                    <p className="text-xs text-navy-500">{r.referred_owner_email}</p>
                  </td>
                  <td className="px-4 py-3 text-navy-400">{fmtDateTime(r.registered_at)}</td>
                  <td className="px-4 py-3"><Badge label={r.status} color={STATUS_COLORS[r.status]} /></td>
                  <td className="px-4 py-3 text-xs text-navy-500">{r.reject_reason || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {!loading && rows.length > 0 && (
          <PaginationFooter page={page} pageSize={PAGE_SIZE} count={count} onPageChange={setPage} />
        )}
      </div>
    </div>
  );
}
