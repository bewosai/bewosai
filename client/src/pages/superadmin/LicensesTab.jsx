import { useState, useEffect, useCallback, useMemo } from "react";
import { superadmin as adminApi } from "../../api";
import { Badge, ConfirmDialog } from "../SuperAdminPage";
import {
  Plus, Copy, Check, X, RefreshCw, Search, Loader,
  Ban, Clock, KeyRound,
} from "lucide-react";

const DURATION_LABELS = { "7D": "7 Days", "30D": "30 Days", "1Y": "1 Year", "5Y": "5 Years", CUSTOM: "Custom" };
const DURATION_OPTIONS = ["7D", "30D", "1Y", "5Y", "CUSTOM"];
const STATUS_OPTIONS = ["PENDING", "ACTIVE", "EXPIRED", "REVOKED"];
const STATUS_COLORS = { PENDING: "gray", ACTIVE: "green", EXPIRED: "orange", REVOKED: "red" };

function fmtDate(d) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });
}

/* ── Generate License modal ─────────────────────────────────────────────── */
function GenerateLicenseModal({ businesses, onClose, onGenerated }) {
  const [businessId, setBusinessId] = useState("");
  const [businessSearch, setBusinessSearch] = useState("");
  const [durationType, setDurationType] = useState("30D");
  const [customDays, setCustomDays] = useState(30);
  const [startDate, setStartDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);
  const [copied, setCopied] = useState(false);

  const filteredBusinesses = useMemo(() => {
    const q = businessSearch.trim().toLowerCase();
    if (!q) return businesses.slice(0, 30);
    return businesses.filter(
      (b) => b.name.toLowerCase().includes(q) || (b.owner_name || "").toLowerCase().includes(q)
    ).slice(0, 30);
  }, [businesses, businessSearch]);

  const selectedBusiness = businesses.find((b) => String(b.id) === String(businessId));

  const handleGenerate = async () => {
    if (!businessId) { setError("Select a business."); return; }
    if (durationType === "CUSTOM" && (!customDays || customDays < 1)) {
      setError("Enter a valid number of days."); return;
    }
    setSaving(true);
    setError("");
    try {
      const { data } = await adminApi.generateLicense({
        business: businessId,
        duration_type: durationType,
        duration_days: durationType === "CUSTOM" ? Number(customDays) : undefined,
        start_date: startDate,
      });
      setResult(data);
      onGenerated();
    } catch (err) {
      setError(err.response?.data?.error || "Could not generate the license.");
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
            <h3 className="text-lg font-bold text-white">License Created Successfully</h3>
            <button
              onClick={copyCode}
              className="mx-auto mt-4 flex items-center gap-3 rounded-2xl border-2 border-dashed border-orange-500/40 bg-orange-500/5 px-6 py-4 text-2xl font-bold tracking-[0.3em] text-orange-400 hover:bg-orange-500/10"
            >
              {result.code}
              {copied ? <Check className="h-5 w-5 text-green-400" /> : <Copy className="h-5 w-5" />}
            </button>
            <div className="mt-4 space-y-1 text-left text-sm text-navy-300">
              <p><span className="text-navy-500">Business:</span> {result.business_name}</p>
              <p><span className="text-navy-500">Duration:</span> {DURATION_LABELS[result.duration_type]}</p>
              <p><span className="text-navy-500">Start:</span> {fmtDate(result.start_date)}</p>
              <p><span className="text-navy-500">Expiry:</span> {fmtDate(result.expiry_date)}</p>
            </div>
            <button onClick={onClose} className="mt-6 w-full rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600">
              Done
            </button>
          </div>
        ) : (
          <>
            <div className="mb-4 flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">Generate License</h3>
              <button onClick={onClose} className="text-navy-400 hover:text-white"><X className="h-5 w-5" /></button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="mb-1.5 block text-xs font-semibold text-navy-400">Business</label>
                {selectedBusiness ? (
                  <div className="flex items-center justify-between rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5">
                    <div>
                      <p className="text-sm font-semibold text-white">{selectedBusiness.name}</p>
                      <p className="text-xs text-navy-500">{selectedBusiness.owner_name}</p>
                    </div>
                    <button onClick={() => setBusinessId("")} className="text-xs text-orange-400 hover:underline">Change</button>
                  </div>
                ) : (
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
                    <input
                      value={businessSearch}
                      onChange={(e) => setBusinessSearch(e.target.value)}
                      placeholder="Search business name or owner…"
                      className="w-full rounded-xl border border-navy-700 bg-navy-950 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-navy-600 focus:border-orange-500 focus:outline-none"
                    />
                    {businessSearch && (
                      <div className="absolute z-10 mt-1 max-h-48 w-full overflow-y-auto rounded-xl border border-navy-700 bg-navy-900 shadow-xl">
                        {filteredBusinesses.length === 0 ? (
                          <p className="px-3 py-2.5 text-xs text-navy-500">No matches</p>
                        ) : (
                          filteredBusinesses.map((b) => (
                            <button
                              key={b.id}
                              onClick={() => { setBusinessId(String(b.id)); setBusinessSearch(""); }}
                              className="flex w-full flex-col items-start px-3 py-2 text-left hover:bg-navy-800"
                            >
                              <span className="text-sm text-white">{b.name}</span>
                              <span className="text-xs text-navy-500">{b.owner_name}</span>
                            </button>
                          ))
                        )}
                      </div>
                    )}
                  </div>
                )}
              </div>

              <div>
                <label className="mb-1.5 block text-xs font-semibold text-navy-400">Duration</label>
                <div className="grid grid-cols-3 gap-2">
                  {DURATION_OPTIONS.map((d) => (
                    <button
                      key={d}
                      onClick={() => setDurationType(d)}
                      className={`rounded-lg border py-2 text-xs font-semibold transition ${
                        durationType === d ? "border-orange-500 bg-orange-500/10 text-orange-400" : "border-navy-700 text-navy-400 hover:border-navy-600"
                      }`}
                    >
                      {DURATION_LABELS[d]}
                    </button>
                  ))}
                </div>
                {durationType === "CUSTOM" && (
                  <input
                    type="number"
                    min={1}
                    value={customDays}
                    onChange={(e) => setCustomDays(e.target.value)}
                    placeholder="Number of days"
                    className="mt-2 w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white focus:border-orange-500 focus:outline-none"
                  />
                )}
              </div>

              <div>
                <label className="mb-1.5 block text-xs font-semibold text-navy-400">Start Date</label>
                <input
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white focus:border-orange-500 focus:outline-none"
                />
              </div>

              {error && <p className="text-sm text-red-400">{error}</p>}

              <button
                onClick={handleGenerate}
                disabled={saving || !businessId}
                className="flex w-full items-center justify-center gap-2 rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50"
              >
                {saving ? <Loader className="h-4 w-4 animate-spin" /> : <KeyRound className="h-4 w-4" />}
                {saving ? "Generating…" : "Generate License"}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/* ── Extend modal ────────────────────────────────────────────────────────── */
function ExtendModal({ license, onClose, onExtended }) {
  const [durationType, setDurationType] = useState("30D");
  const [customDays, setCustomDays] = useState(30);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const handleExtend = async () => {
    setSaving(true);
    setError("");
    try {
      await adminApi.extendLicense(license.id, {
        duration_type: durationType,
        duration_days: durationType === "CUSTOM" ? Number(customDays) : undefined,
      });
      onExtended();
      onClose();
    } catch (err) {
      setError(err.response?.data?.error || "Could not extend the license.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-sm rounded-2xl border border-navy-700 bg-navy-900 p-6 space-y-4">
        <h3 className="text-lg font-bold text-white">Extend License</h3>
        <p className="text-sm text-navy-400">
          Code <span className="font-mono font-bold text-white">{license.code}</span> — currently expires {fmtDate(license.expiry_date)}
        </p>
        <div className="grid grid-cols-2 gap-2">
          {["30D", "1Y", "5Y", "CUSTOM"].map((d) => (
            <button
              key={d}
              onClick={() => setDurationType(d)}
              className={`rounded-lg border py-2 text-xs font-semibold ${
                durationType === d ? "border-orange-500 bg-orange-500/10 text-orange-400" : "border-navy-700 text-navy-400"
              }`}
            >
              {DURATION_LABELS[d]}
            </button>
          ))}
        </div>
        {durationType === "CUSTOM" && (
          <input
            type="number"
            min={1}
            value={customDays}
            onChange={(e) => setCustomDays(e.target.value)}
            className="w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white"
          />
        )}
        {error && <p className="text-sm text-red-400">{error}</p>}
        <div className="flex gap-3">
          <button onClick={onClose} className="flex-1 rounded-xl border border-navy-700 py-2.5 text-sm text-navy-400 hover:bg-navy-800">Cancel</button>
          <button onClick={handleExtend} disabled={saving} className="flex-1 rounded-xl bg-orange-500 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50">
            {saving ? "Extending…" : "Extend"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Main tab ────────────────────────────────────────────────────────────── */
export default function LicensesTab({ businesses }) {
  const [rows, setRows] = useState([]);
  const [years, setYears] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({ duration_type: "", status: "", year: "", search: "" });
  const [showGenerate, setShowGenerate] = useState(false);
  const [extendTarget, setExtendTarget] = useState(null);
  const [revokeTarget, setRevokeTarget] = useState(null);
  const [busyId, setBusyId] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = {};
      Object.entries(filters).forEach(([k, v]) => { if (v) params[k] = v; });
      const [list, yrs] = await Promise.all([
        adminApi.licenseList(params),
        adminApi.licenseYears(),
      ]);
      setRows(list.data?.results ?? list.data ?? []);
      setYears(yrs.data ?? []);
    } catch {
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [filters]);

  useEffect(() => { load(); }, [load]);

  const handleRevoke = async () => {
    setBusyId(revokeTarget.id);
    try {
      await adminApi.revokeLicense(revokeTarget.id);
      await load();
    } catch {}
    setBusyId(null);
    setRevokeTarget(null);
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-navy-500">
          Premium license codes — trial ends after the configured window, and business endpoints stay
          blocked until an active license is entered.
        </p>
        <button
          onClick={() => setShowGenerate(true)}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600"
        >
          <Plus className="h-4 w-4" /> Generate License
        </button>
      </div>

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
          value={filters.duration_type}
          onChange={(e) => setFilters((f) => ({ ...f, duration_type: e.target.value }))}
          className="rounded-lg border border-navy-700 bg-navy-900 px-3 py-2 text-xs text-navy-300 focus:border-orange-500 focus:outline-none"
        >
          <option value="">All Durations</option>
          {DURATION_OPTIONS.map((d) => <option key={d} value={d}>{DURATION_LABELS[d]}</option>)}
        </select>
        <select
          value={filters.status}
          onChange={(e) => setFilters((f) => ({ ...f, status: e.target.value }))}
          className="rounded-lg border border-navy-700 bg-navy-900 px-3 py-2 text-xs text-navy-300 focus:border-orange-500 focus:outline-none"
        >
          <option value="">All Statuses</option>
          {STATUS_OPTIONS.map((s) => <option key={s} value={s}>{s.charAt(0) + s.slice(1).toLowerCase()}</option>)}
        </select>
        <select
          value={filters.year}
          onChange={(e) => setFilters((f) => ({ ...f, year: e.target.value }))}
          className="rounded-lg border border-navy-700 bg-navy-900 px-3 py-2 text-xs text-navy-300 focus:border-orange-500 focus:outline-none"
        >
          <option value="">All Years</option>
          {years.map((y) => <option key={y} value={y}>{y}</option>)}
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
          <p className="px-4 py-10 text-center text-sm text-navy-500">No licenses match these filters.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-navy-800 text-left text-xs text-navy-500">
                <th className="px-4 py-3 font-medium">Code</th>
                <th className="px-4 py-3 font-medium">Business</th>
                <th className="px-4 py-3 font-medium">Duration</th>
                <th className="px-4 py-3 font-medium">Start</th>
                <th className="px-4 py-3 font-medium">Expiry</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-navy-800/50">
              {rows.map((lic) => (
                <tr key={lic.id} className="hover:bg-navy-800/30 transition">
                  <td className="px-4 py-3 font-mono font-bold text-white">{lic.code}</td>
                  <td className="px-4 py-3 text-navy-300">{lic.business_name}</td>
                  <td className="px-4 py-3 text-navy-300">{DURATION_LABELS[lic.duration_type] || lic.duration_type}</td>
                  <td className="px-4 py-3 text-navy-400">{fmtDate(lic.start_date)}</td>
                  <td className="px-4 py-3 text-navy-400">{fmtDate(lic.expiry_date)}</td>
                  <td className="px-4 py-3"><Badge label={lic.status} color={STATUS_COLORS[lic.status]} /></td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-end gap-2">
                      {lic.status !== "REVOKED" && (
                        <button
                          onClick={() => setExtendTarget(lic)}
                          title="Extend"
                          className="rounded-lg p-1.5 text-navy-400 hover:bg-navy-800 hover:text-orange-400"
                        >
                          <Clock className="h-4 w-4" />
                        </button>
                      )}
                      {lic.status !== "REVOKED" && (
                        <button
                          onClick={() => setRevokeTarget(lic)}
                          disabled={busyId === lic.id}
                          title="Revoke"
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
      </div>

      {showGenerate && (
        <GenerateLicenseModal
          businesses={businesses}
          onClose={() => setShowGenerate(false)}
          onGenerated={load}
        />
      )}
      {extendTarget && (
        <ExtendModal license={extendTarget} onClose={() => setExtendTarget(null)} onExtended={load} />
      )}
      {revokeTarget && (
        <ConfirmDialog
          title="Revoke this license?"
          body="This will immediately disable premium access for the business using it."
          dangerous
          onCancel={() => setRevokeTarget(null)}
          onConfirm={handleRevoke}
        />
      )}
    </div>
  );
}
