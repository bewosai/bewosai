import { useState, useEffect, useCallback, useMemo } from "react";
import { superadmin as adminApi } from "../../api";
import { Badge, ConfirmDialog, PaginationFooter } from "../SuperAdminPage";
import { Plus, Copy, Check, X, RefreshCw, Search, Loader, Ban, Ticket } from "lucide-react";
import { todayStr, formatDateOnly } from "../../utils/dates";

const PAGE_SIZE = 50;

const PLAN_LABELS = { PREMIUM: "Premium", PREMIUMPLUS: "Premium Plus" };
const PLAN_OPTIONS = ["PREMIUM", "PREMIUMPLUS"];
const STATUS_OPTIONS = ["ACTIVE", "USED", "EXPIRED", "CANCELLED"];
const STATUS_COLORS = { ACTIVE: "green", USED: "blue", EXPIRED: "orange", CANCELLED: "red" };

// Quick duration picks, computed relative to the chosen start date —
// mirrors LicensesTab's DURATION_OPTIONS pattern but expressed as day
// counts since Coupon has no duration_type field of its own (just plain
// start_date/end_date, set directly by whoever's creating it).
const DURATION_PRESETS = [
  { label: "7 Days", days: 7 },
  { label: "1 Month", days: 30 },
  { label: "3 Months", days: 90 },
  { label: "6 Months", days: 180 },
  { label: "1 Year", days: 365 },
];

function fmtDate(d) {
  // The Nepal calendar day, not the browser's own — see utils/dates.js.
  return formatDateOnly(d);
}

function addDays(dateStr, days) {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

/* ── Create Coupon modal ─────────────────────────────────────────────────── */
function CreateCouponModal({ onClose, onCreated }) {
  const [userSearch, setUserSearch] = useState("");
  const [userResults, setUserResults] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [plan, setPlan] = useState("PREMIUM");
  const [startDate, setStartDate] = useState(() => todayStr());
  const [endDate, setEndDate] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!userSearch.trim() || selectedUser) { setUserResults([]); return; }
    let cancelled = false;
    adminApi.users({ search: userSearch, page_size: 10 })
      .then((r) => { if (!cancelled) setUserResults(r.data?.results ?? r.data ?? []); })
      .catch(() => { if (!cancelled) setUserResults([]); });
    return () => { cancelled = true; };
  }, [userSearch, selectedUser]);

  const customDays = useMemo(() => {
    if (!endDate || !startDate) return 0;
    return Math.max(1, Math.round((new Date(endDate) - new Date(startDate)) / 86400000));
  }, [startDate, endDate]);

  const handleCreate = async () => {
    if (!selectedUser) { setError("Search for and select a user."); return; }
    if (!endDate) { setError("Pick an end date, or use a quick duration above."); return; }
    if (customDays < 1) { setError("End date must be after the start date."); return; }
    setSaving(true);
    setError("");
    try {
      const { data } = await adminApi.createCoupon({
        user: selectedUser.id, plan, start_date: startDate, end_date: endDate,
      });
      setResult(data);
      onCreated();
    } catch (err) {
      setError(err.response?.data?.message || err.response?.data?.error || "Could not create the coupon.");
    } finally {
      setSaving(false);
    }
  };

  const copyCode = () => {
    navigator.clipboard.writeText(result.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        {result ? (
          <div className="text-center">
            <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-green-500/15">
              <Check className="h-7 w-7 text-green-400" />
            </div>
            <h3 className="text-lg font-bold text-white">Coupon Created</h3>
            <button
              onClick={copyCode}
              className="mx-auto mt-4 flex items-center gap-3 rounded-2xl border-2 border-dashed border-orange-500/40 bg-orange-500/5 px-6 py-4 text-2xl font-bold tracking-[0.3em] text-orange-400 hover:bg-orange-500/10"
            >
              {result.code}
              {copied ? <Check className="h-5 w-5 text-green-400" /> : <Copy className="h-5 w-5" />}
            </button>
            <div className="mt-4 space-y-1 text-left text-sm text-navy-300">
              <p><span className="text-navy-500">User:</span> {result.user_name || result.user_email}</p>
              <p><span className="text-navy-500">Plan:</span> {PLAN_LABELS[result.plan]}</p>
              <p><span className="text-navy-500">Valid:</span> {fmtDate(result.start_date)} → {fmtDate(result.end_date)}</p>
            </div>
            <button onClick={onClose} className="mt-6 w-full rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600">
              Done
            </button>
          </div>
        ) : (
          <>
            <div className="mb-4 flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">Create Coupon</h3>
              <button onClick={onClose} className="text-navy-400 hover:text-white"><X className="h-5 w-5" /></button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="mb-1.5 block text-xs font-semibold text-navy-400">User</label>
                {selectedUser ? (
                  <div className="flex items-center justify-between rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5">
                    <div>
                      <p className="text-sm font-semibold text-white">{selectedUser.name || "—"}</p>
                      <p className="text-xs text-navy-500">{selectedUser.email || selectedUser.phone}</p>
                    </div>
                    <button onClick={() => { setSelectedUser(null); setUserSearch(""); }} className="text-xs text-orange-400 hover:underline">Change</button>
                  </div>
                ) : (
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
                    <input
                      value={userSearch}
                      onChange={(e) => setUserSearch(e.target.value)}
                      placeholder="Search by email, phone, or name…"
                      className="w-full rounded-xl border border-navy-700 bg-navy-950 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-navy-600 focus:border-orange-500 focus:outline-none"
                    />
                    {userSearch && (
                      <div className="absolute z-10 mt-1 max-h-48 w-full overflow-y-auto rounded-xl border border-navy-700 bg-navy-900 shadow-xl">
                        {userResults.length === 0 ? (
                          <p className="px-3 py-2.5 text-xs text-navy-500">No matches</p>
                        ) : (
                          userResults.map((u) => (
                            <button
                              key={u.id}
                              onClick={() => { setSelectedUser(u); setUserSearch(""); }}
                              className="flex w-full flex-col items-start px-3 py-2 text-left hover:bg-navy-800"
                            >
                              <span className="text-sm text-white">{u.name || "—"}</span>
                              <span className="text-xs text-navy-500">{u.email || u.phone}</span>
                            </button>
                          ))
                        )}
                      </div>
                    )}
                  </div>
                )}
              </div>

              <div>
                <label className="mb-1.5 block text-xs font-semibold text-navy-400">Plan</label>
                <div className="grid grid-cols-2 gap-2">
                  {PLAN_OPTIONS.map((p) => (
                    <button
                      key={p}
                      onClick={() => setPlan(p)}
                      className={`rounded-lg border py-2 text-xs font-semibold transition ${
                        plan === p ? "border-orange-500 bg-orange-500/10 text-orange-400" : "border-navy-700 text-navy-400 hover:border-navy-600"
                      }`}
                    >
                      {PLAN_LABELS[p]}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="mb-1.5 block text-xs font-semibold text-navy-400">Duration</label>
                <div className="grid grid-cols-3 gap-2">
                  {DURATION_PRESETS.map((d) => (
                    <button
                      key={d.label}
                      onClick={() => setEndDate(addDays(startDate, d.days))}
                      className="rounded-lg border border-navy-700 py-2 text-xs font-semibold text-navy-400 transition hover:border-orange-500/50 hover:text-orange-400"
                    >
                      {d.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="mb-1.5 block text-xs font-semibold text-navy-400">Start Date</label>
                  <input
                    type="date"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    className="w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white focus:border-orange-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1.5 block text-xs font-semibold text-navy-400">End Date</label>
                  <input
                    type="date"
                    min={startDate}
                    value={endDate}
                    onChange={(e) => setEndDate(e.target.value)}
                    className="w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white focus:border-orange-500 focus:outline-none"
                  />
                </div>
              </div>
              {endDate && (
                <p className="-mt-2 text-[11px] text-navy-500">{customDays} day{customDays === 1 ? "" : "s"}</p>
              )}

              {error && <p className="text-sm text-red-400">{error}</p>}

              <button
                onClick={handleCreate}
                disabled={saving || !selectedUser}
                className="flex w-full items-center justify-center gap-2 rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50"
              >
                {saving ? <Loader className="h-4 w-4 animate-spin" /> : <Ticket className="h-4 w-4" />}
                {saving ? "Creating…" : "Create Coupon"}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/* ── Main tab ────────────────────────────────────────────────────────────── */
export default function CouponsTab() {
  const [rows, setRows] = useState([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({ plan: "", status: "", search: "" });
  const [showCreate, setShowCreate] = useState(false);
  const [deactivateTarget, setDeactivateTarget] = useState(null);
  const [deactivateError, setDeactivateError] = useState("");
  const [busyId, setBusyId] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, page_size: PAGE_SIZE };
      Object.entries(filters).forEach(([k, v]) => { if (v) params[k] = v; });
      const { data } = await adminApi.couponList(params);
      setRows(data?.results ?? data ?? []);
      setCount(data?.count ?? (Array.isArray(data) ? data.length : 0));
    } catch {
      setRows([]);
      setCount(0);
    } finally {
      setLoading(false);
    }
  }, [filters, page]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [filters]);

  const handleDeactivate = async () => {
    setBusyId(deactivateTarget.id);
    setDeactivateError("");
    try {
      await adminApi.deactivateCoupon(deactivateTarget.id);
      await load();
      setDeactivateTarget(null);
    } catch (err) {
      setDeactivateError(err.response?.data?.message || err.response?.data?.error || "Could not deactivate this coupon.");
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-navy-500">
          Manually grant Premium or Premium Plus to a specific verified user — a 6-character code
          they redeem from Settings → Upgrade Plan. Kept separate from Licensing.
        </p>
        <button
          onClick={() => setShowCreate(true)}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600"
        >
          <Plus className="h-4 w-4" /> Create Coupon
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-2">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
          <input
            value={filters.search}
            onChange={(e) => setFilters((f) => ({ ...f, search: e.target.value }))}
            placeholder="Search code / user…"
            className="w-56 rounded-lg border border-navy-700 bg-navy-900 py-2 pl-9 pr-3 text-xs text-white placeholder:text-navy-600 focus:border-orange-500 focus:outline-none"
          />
        </div>
        <select
          value={filters.plan}
          onChange={(e) => setFilters((f) => ({ ...f, plan: e.target.value }))}
          className="rounded-lg border border-navy-700 bg-navy-900 px-3 py-2 text-xs text-navy-300 focus:border-orange-500 focus:outline-none"
        >
          <option value="">All Plans</option>
          {PLAN_OPTIONS.map((p) => <option key={p} value={p}>{PLAN_LABELS[p]}</option>)}
        </select>
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
          <p className="px-4 py-10 text-center text-sm text-navy-500">No coupons match these filters.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-navy-800 text-left text-xs text-navy-500">
                <th className="px-4 py-3 font-medium">Code</th>
                <th className="px-4 py-3 font-medium">User</th>
                <th className="px-4 py-3 font-medium">Plan</th>
                <th className="px-4 py-3 font-medium">Source</th>
                <th className="px-4 py-3 font-medium">Valid Until</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-navy-800/50">
              {rows.map((c) => (
                <tr key={c.id} className="hover:bg-navy-800/30 transition">
                  <td className="px-4 py-3 font-mono font-bold text-white">{c.code}</td>
                  <td className="px-4 py-3 text-navy-300">
                    <p>{c.user_name || "—"}</p>
                    <p className="text-xs text-navy-500">{c.user_email || c.user_phone}</p>
                  </td>
                  <td className="px-4 py-3 text-navy-300">{PLAN_LABELS[c.plan] || c.plan}</td>
                  <td className="px-4 py-3 text-navy-400">{c.source === "REFERRAL" ? "Referral" : "Admin"}</td>
                  <td className="px-4 py-3 text-navy-400">{fmtDate(c.end_date)}</td>
                  <td className="px-4 py-3"><Badge label={c.status} color={STATUS_COLORS[c.status]} /></td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-end gap-2">
                      {c.status === "ACTIVE" && (
                        <button
                          onClick={() => setDeactivateTarget(c)}
                          disabled={busyId === c.id}
                          title="Deactivate"
                          className="rounded-lg p-1.5 text-navy-400 hover:bg-navy-800 hover:text-red-400 disabled:opacity-50"
                        >
                          <Ban className="h-4 w-4" />
                        </button>
                      )}
                    </div>
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

      {showCreate && (
        <CreateCouponModal onClose={() => setShowCreate(false)} onCreated={load} />
      )}
      {deactivateTarget && (
        <ConfirmDialog
          title="Deactivate this coupon?"
          body="It will no longer be usable, even if it hasn't expired yet."
          error={deactivateError}
          busy={busyId === deactivateTarget.id}
          dangerous
          onCancel={() => { setDeactivateTarget(null); setDeactivateError(""); }}
          onConfirm={handleDeactivate}
        />
      )}
    </div>
  );
}
