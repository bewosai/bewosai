import { useState, useEffect, useCallback } from "react";
import { superadmin as adminApi } from "../../api";
import { Badge, PaginationFooter } from "../SuperAdminPage";
import { RefreshCw, Search, Loader, LogIn, Activity as ActivityIcon, CheckCircle2, XCircle } from "lucide-react";

const PAGE_SIZE = 50;
const ACTION_COLORS = { CREATED: "green", DELETED: "red" };

function fmtDateTime(d) {
  if (!d) return "—";
  return new Date(d).toLocaleString(undefined, { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

function SubTabButton({ active, onClick, icon: Icon, label }) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold transition ${
        active ? "bg-orange-500 text-white" : "text-navy-400 hover:bg-navy-800 hover:text-white"
      }`}
    >
      <Icon className="h-3.5 w-3.5" /> {label}
    </button>
  );
}

/* ─── Every login, every user, by name — not just an email address, so
     Super Admin can actually recognize who's who at a glance. ─────────── */
function LoginActivitySection() {
  const [rows, setRows] = useState([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, page_size: PAGE_SIZE };
      if (search) params.search = search;
      const { data } = await adminApi.loginActivity(params);
      setRows(data?.results ?? data ?? []);
      setCount(data?.count ?? (Array.isArray(data) ? data.length : 0));
    } catch {
      setRows([]);
      setCount(0);
    } finally {
      setLoading(false);
    }
  }, [page, search]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [search]);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name / email / phone…"
            className="w-64 rounded-lg border border-navy-700 bg-navy-900 py-2 pl-9 pr-3 text-xs text-white placeholder:text-navy-600 focus:border-orange-500 focus:outline-none"
          />
        </div>
        <button onClick={load} className="flex items-center gap-1.5 rounded-lg border border-navy-700 px-3 py-2 text-xs text-navy-400 hover:bg-navy-800">
          <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} /> Refresh
        </button>
      </div>

      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
        {loading ? (
          <div className="flex justify-center py-16"><Loader className="h-5 w-5 animate-spin text-orange-500" /></div>
        ) : rows.length === 0 ? (
          <p className="px-4 py-10 text-center text-sm text-navy-500">No login activity yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-navy-800 text-left text-xs text-navy-500">
                <th className="px-4 py-3 font-medium">User</th>
                <th className="px-4 py-3 font-medium">Device</th>
                <th className="px-4 py-3 font-medium">IP</th>
                <th className="px-4 py-3 font-medium">Logged In</th>
                <th className="px-4 py-3 font-medium">Session</th>
                <th className="px-4 py-3 font-medium">Result</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-navy-800/50">
              {rows.map((r) => (
                <tr key={r.id} className="hover:bg-navy-800/30 transition">
                  <td className="px-4 py-3 text-navy-300">
                    <p className="text-white">{r.user_name || "—"}</p>
                    <p className="text-xs text-navy-500">{r.user}</p>
                  </td>
                  <td className="px-4 py-3 text-navy-400">{r.device}</td>
                  <td className="px-4 py-3 text-navy-400">{r.ip || "—"}</td>
                  <td className="px-4 py-3 text-navy-400">{fmtDateTime(r.timestamp)}</td>
                  <td className="px-4 py-3 text-navy-400">{r.session_duration || "—"}</td>
                  <td className="px-4 py-3">
                    {r.success ? (
                      <span className="flex items-center gap-1 text-xs text-green-400"><CheckCircle2 className="h-3.5 w-3.5" /> Success</span>
                    ) : (
                      <span className="flex items-center gap-1 text-xs text-red-400"><XCircle className="h-3.5 w-3.5" /> Failed</span>
                    )}
                  </td>
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

/* ─── Every create/delete, anywhere in the app, by anyone — the platform-
     wide audit trail (see superadmin.ActivityLog / signals.py). ─────────── */
function AppActivitySection() {
  const [rows, setRows] = useState([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({ action: "", search: "" });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, page_size: PAGE_SIZE };
      Object.entries(filters).forEach(([k, v]) => { if (v) params[k] = v; });
      const { data } = await adminApi.activityLog(params);
      setRows(data?.results ?? data ?? []);
      setCount(data?.count ?? (Array.isArray(data) ? data.length : 0));
    } catch {
      setRows([]);
      setCount(0);
    } finally {
      setLoading(false);
    }
  }, [page, filters]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [filters]);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
          <input
            value={filters.search}
            onChange={(e) => setFilters((f) => ({ ...f, search: e.target.value }))}
            placeholder="Search user / business / item…"
            className="w-64 rounded-lg border border-navy-700 bg-navy-900 py-2 pl-9 pr-3 text-xs text-white placeholder:text-navy-600 focus:border-orange-500 focus:outline-none"
          />
        </div>
        <select
          value={filters.action}
          onChange={(e) => setFilters((f) => ({ ...f, action: e.target.value }))}
          className="rounded-lg border border-navy-700 bg-navy-900 px-3 py-2 text-xs text-navy-300 focus:border-orange-500 focus:outline-none"
        >
          <option value="">All Actions</option>
          <option value="CREATED">Created</option>
          <option value="DELETED">Deleted</option>
        </select>
        <button onClick={load} className="flex items-center gap-1.5 rounded-lg border border-navy-700 px-3 py-2 text-xs text-navy-400 hover:bg-navy-800">
          <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} /> Refresh
        </button>
      </div>

      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
        {loading ? (
          <div className="flex justify-center py-16"><Loader className="h-5 w-5 animate-spin text-orange-500" /></div>
        ) : rows.length === 0 ? (
          <p className="px-4 py-10 text-center text-sm text-navy-500">No activity matches these filters.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-navy-800 text-left text-xs text-navy-500">
                <th className="px-4 py-3 font-medium">User</th>
                <th className="px-4 py-3 font-medium">Business</th>
                <th className="px-4 py-3 font-medium">Action</th>
                <th className="px-4 py-3 font-medium">Item</th>
                <th className="px-4 py-3 font-medium">When</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-navy-800/50">
              {rows.map((r) => (
                <tr key={r.id} className="hover:bg-navy-800/30 transition">
                  <td className="px-4 py-3 text-white">{r.user_name || "—"}</td>
                  <td className="px-4 py-3 text-navy-400">{r.business_name}</td>
                  <td className="px-4 py-3"><Badge label={r.action} color={ACTION_COLORS[r.action]} /></td>
                  <td className="px-4 py-3 text-navy-300">
                    <span className="text-navy-500">{r.model_name}</span> · {r.object_repr}
                  </td>
                  <td className="px-4 py-3 text-navy-400">{fmtDateTime(r.created_at)}</td>
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

export default function ActivityTab() {
  const [sub, setSub] = useState("logins");

  return (
    <div className="space-y-4">
      <p className="text-xs text-navy-500">
        Track every login and every create/delete across the whole platform, by name — not just business owners, every user.
      </p>
      <div className="flex gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1 w-fit">
        <SubTabButton active={sub === "logins"} onClick={() => setSub("logins")} icon={LogIn} label="Login Activity" />
        <SubTabButton active={sub === "app"} onClick={() => setSub("app")} icon={ActivityIcon} label="App Activity" />
      </div>
      {sub === "logins" ? <LoginActivitySection /> : <AppActivitySection />}
    </div>
  );
}
