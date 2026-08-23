import { useState, useEffect, useMemo, useCallback } from "react";
import { superadmin as adminApi } from "../api";
import { useAuth } from "../context/AuthContext";
import { useTranslation } from "../utils/translations";
import { useNavigate } from "react-router-dom";
import {
  adToBS, BS_MONTH_NAMES_EN, BS_MONTH_NAMES_NE,
  bsMonthStartWeekday, getBSMonthADDates, formatBS, toNepaliDigits,
} from "../utils/nepaliDate";
import {
  Users, Building2, ShieldCheck, CheckCircle2, XCircle, X,
  CalendarDays, ChevronLeft, ChevronRight, Plus, Edit2,
  Trash2, MessageSquare, Bell, Search, RefreshCw, Loader,
  TrendingUp, AlertTriangle, ToggleLeft, ToggleRight, Crown,
  SlidersHorizontal, Monitor, Smartphone, KeyRound, LayoutDashboard,
} from "lucide-react";
import LicensesTab from "./superadmin/LicensesTab";

/* ── helpers ─────────────────────────────────────────────────────────────── */

export function Badge({ label, color = "gray" }) {
  const map = {
    green: "bg-green-500/10 text-green-400",
    red: "bg-red-500/10 text-red-400",
    orange: "bg-orange-500/10 text-orange-400",
    blue: "bg-blue-500/10 text-blue-400",
    gray: "bg-navy-700 text-navy-300",
    yellow: "bg-yellow-500/10 text-yellow-400",
  };
  return (
    <span className={`inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold ${map[color] || map.gray}`}>
      {label}
    </span>
  );
}

/** Debounces a fast-changing value (e.g. a search input) so callers can key
 * a network fetch off it without firing a request on every keystroke. */
function useDebounced(value, delayMs = 350) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(t);
  }, [value, delayMs]);
  return debounced;
}

/** "Showing X to Y of Z results" footer with Previous/page-number/Next controls,
 * for any endpoint using LargePageNumberPagination's {count, results} shape. */
export function PaginationFooter({ page, pageSize, count, onPageChange }) {
  const totalPages = Math.max(1, Math.ceil(count / pageSize));
  if (totalPages <= 1 && count <= pageSize) {
    return (
      <div className="border-t border-navy-800 px-4 py-3">
        <p className="text-xs text-navy-500">{count} result{count === 1 ? "" : "s"}</p>
      </div>
    );
  }
  const from = count === 0 ? 0 : (page - 1) * pageSize + 1;
  const to = Math.min(page * pageSize, count);

  // A compact window of page numbers around the current one, plus the
  // first/last page and "…" gaps — avoids rendering hundreds of page
  // buttons when count is large (matches the reference's "1 2 3 4 5 … 961").
  const pages = [];
  const windowStart = Math.max(2, page - 1);
  const windowEnd = Math.min(totalPages - 1, page + 1);
  pages.push(1);
  if (windowStart > 2) pages.push("…");
  for (let p = windowStart; p <= windowEnd; p++) pages.push(p);
  if (windowEnd < totalPages - 1) pages.push("…");
  if (totalPages > 1) pages.push(totalPages);

  return (
    <div className="flex flex-col gap-3 border-t border-navy-800 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
      <p className="text-xs text-navy-500">
        Showing {from} to {to} of {count} results
      </p>
      <div className="flex items-center gap-1">
        <button
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          className="flex items-center gap-1 rounded-lg border border-navy-700 px-2.5 py-1.5 text-xs text-navy-300 hover:bg-navy-800 disabled:opacity-40"
        >
          <ChevronLeft className="h-3.5 w-3.5" /> Previous
        </button>
        {pages.map((p, i) =>
          p === "…" ? (
            <span key={`gap-${i}`} className="px-1.5 text-xs text-navy-600">…</span>
          ) : (
            <button
              key={p}
              onClick={() => onPageChange(p)}
              className={`min-w-[2rem] rounded-lg px-2 py-1.5 text-xs font-semibold transition ${
                p === page ? "bg-orange-500 text-white" : "text-navy-400 hover:bg-navy-800"
              }`}
            >
              {p}
            </button>
          )
        )}
        <button
          disabled={page >= totalPages}
          onClick={() => onPageChange(page + 1)}
          className="flex items-center gap-1 rounded-lg border border-navy-700 px-2.5 py-1.5 text-xs text-navy-300 hover:bg-navy-800 disabled:opacity-40"
        >
          Next <ChevronRight className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}

export function ConfirmDialog({ title, body, error, busy = false, onConfirm, onCancel, dangerous = false }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-sm rounded-2xl border border-navy-700 bg-navy-900 p-6 space-y-4">
        <div className={`mx-auto flex h-12 w-12 items-center justify-center rounded-full ${dangerous ? "bg-red-500/10" : "bg-orange-500/10"}`}>
          <AlertTriangle className={`h-6 w-6 ${dangerous ? "text-red-400" : "text-orange-400"}`} />
        </div>
        <h3 className="text-center text-sm font-bold text-white">{title}</h3>
        {body && <p className="text-center text-xs text-navy-400">{body}</p>}
        {error && <p className="rounded-lg bg-red-500/10 px-3 py-2 text-center text-xs text-red-400">{error}</p>}
        <div className="flex gap-3">
          <button disabled={busy} onClick={onCancel} className="flex-1 rounded-xl border border-navy-700 py-2.5 text-sm font-medium text-navy-400 hover:bg-navy-800 disabled:opacity-50">Cancel</button>
          <button disabled={busy} onClick={onConfirm} className={`flex-1 rounded-xl py-2.5 text-sm font-semibold text-white disabled:opacity-50 ${dangerous ? "bg-red-500 hover:bg-red-600" : "bg-orange-500 hover:bg-orange-600"}`}>
            {busy ? "Working…" : "Confirm"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Login Calendar ──────────────────────────────────────────────────────── */
function LoginCalendar({ loginDates, lang }) {
  const today = new Date();
  const [calMode, setCalMode] = useState("AD");
  const [adYear, setAdYear] = useState(today.getFullYear());
  const [adMonth, setAdMonth] = useState(today.getMonth());
  const todayBS = adToBS(today);
  const [bsYear, setBsYear] = useState(todayBS.year);
  const [bsMonth, setBsMonth] = useState(todayBS.month);

  const loginSet = useMemo(() => {
    const s = new Set();
    loginDates.forEach((d) => {
      const dt = new Date(d);
      s.add(`${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(dt.getDate()).padStart(2, "0")}`);
    });
    return s;
  }, [loginDates]);

  function adKey(y, m, d) {
    return `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
  }

  function renderAD() {
    const firstDay = new Date(adYear, adMonth, 1).getDay();
    const daysInMonth = new Date(adYear, adMonth + 1, 0).getDate();
    const monthName = new Date(adYear, adMonth, 1).toLocaleString("default", { month: "long" });
    const cells = [];
    for (let i = 0; i < firstDay; i++) cells.push(null);
    for (let d = 1; d <= daysInMonth; d++) cells.push(d);
    const prevMonth = () => { if (adMonth === 0) { setAdYear(y => y - 1); setAdMonth(11); } else setAdMonth(m => m - 1); };
    const nextMonth = () => { if (adMonth === 11) { setAdYear(y => y + 1); setAdMonth(0); } else setAdMonth(m => m + 1); };
    return (
      <div>
        <div className="mb-3 flex items-center justify-between">
          <button onClick={prevMonth} className="rounded-lg p-1.5 text-navy-400 hover:bg-navy-800"><ChevronLeft className="h-4 w-4" /></button>
          <p className="text-sm font-semibold text-white">{monthName} {adYear}</p>
          <button onClick={nextMonth} className="rounded-lg p-1.5 text-navy-400 hover:bg-navy-800"><ChevronRight className="h-4 w-4" /></button>
        </div>
        <div className="grid grid-cols-7 gap-0.5 text-center">
          {["Su","Mo","Tu","We","Th","Fr","Sa"].map(d => <div key={d} className="py-1 text-[10px] font-semibold text-navy-400">{d}</div>)}
          {cells.map((day, i) => {
            if (!day) return <div key={`e-${i}`} />;
            const key = adKey(adYear, adMonth, day);
            const hasLogin = loginSet.has(key);
            const isToday = adYear === today.getFullYear() && adMonth === today.getMonth() && day === today.getDate();
            return (
              <div key={day} className={`relative flex h-7 w-full items-center justify-center rounded-lg text-xs ${
                isToday ? "border border-orange-500/50 bg-orange-500/10 font-bold text-orange-400"
                : hasLogin ? "bg-green-500/15 text-green-400 font-medium" : "text-navy-300"
              }`}>
                {day}
                {hasLogin && <span className="absolute bottom-0.5 left-1/2 -translate-x-1/2 h-1 w-1 rounded-full bg-green-400" />}
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  function renderBS() {
    const monthDates = getBSMonthADDates(bsYear, bsMonth);
    const startWd = bsMonthStartWeekday(bsYear, bsMonth);
    const monthLabel = lang === "ne"
      ? `${BS_MONTH_NAMES_NE[bsMonth - 1]} ${toNepaliDigits(bsYear)}`
      : `${BS_MONTH_NAMES_EN[bsMonth - 1]} ${bsYear} BS`;
    const prevMonth = () => { if (bsMonth === 1) { setBsYear(y => y - 1); setBsMonth(12); } else setBsMonth(m => m - 1); };
    const nextMonth = () => { if (bsMonth === 12) { setBsYear(y => y + 1); setBsMonth(1); } else setBsMonth(m => m + 1); };
    const todayBSKey = `${todayBS.year}-${todayBS.month}-${todayBS.day}`;
    const cells = [];
    for (let i = 0; i < startWd; i++) cells.push(null);
    monthDates.forEach(({ bsDay, adDate }) => cells.push({ bsDay, adDate }));
    return (
      <div>
        <div className="mb-3 flex items-center justify-between">
          <button onClick={prevMonth} className="rounded-lg p-1.5 text-navy-400 hover:bg-navy-800"><ChevronLeft className="h-4 w-4" /></button>
          <p className="text-sm font-semibold text-white">{monthLabel}</p>
          <button onClick={nextMonth} className="rounded-lg p-1.5 text-navy-400 hover:bg-navy-800"><ChevronRight className="h-4 w-4" /></button>
        </div>
        <div className="grid grid-cols-7 gap-0.5 text-center">
          {["आ","सो","मं","बु","वि","शु","श"].map(d => <div key={d} className="py-1 text-[10px] font-semibold text-navy-400">{d}</div>)}
          {cells.map((cell, i) => {
            if (!cell) return <div key={`e-${i}`} />;
            const { bsDay, adDate } = cell;
            const adKey2 = `${adDate.getFullYear()}-${String(adDate.getMonth() + 1).padStart(2, "0")}-${String(adDate.getDate()).padStart(2, "0")}`;
            const hasLogin = loginSet.has(adKey2);
            const isToday = `${bsYear}-${bsMonth}-${bsDay}` === todayBSKey;
            return (
              <div key={bsDay} className={`relative flex h-7 w-full items-center justify-center rounded-lg text-xs ${
                isToday ? "border border-orange-500/50 bg-orange-500/10 font-bold text-orange-400"
                : hasLogin ? "bg-green-500/15 text-green-400 font-medium" : "text-navy-300"
              }`}>
                {lang === "ne" ? toNepaliDigits(bsDay) : bsDay}
                {hasLogin && <span className="absolute bottom-0.5 left-1/2 -translate-x-1/2 h-1 w-1 rounded-full bg-green-400" />}
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-4 flex gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1 w-fit">
        {["AD", "BS"].map(m => (
          <button key={m} onClick={() => setCalMode(m)}
            className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${calMode === m ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}>
            {m}
          </button>
        ))}
      </div>
      {calMode === "AD" ? renderAD() : renderBS()}
    </div>
  );
}

/* ── User Detail Modal ────────────────────────────────────────────────────── */
function UserDetailModal({ user: u, onClose, onAction }) {
  const { language } = useTranslation();
  const [activity, setActivity] = useState([]);
  const [loading, setLoading] = useState(true);
  const [acting, setActing] = useState(false);

  useEffect(() => {
    adminApi.userLoginActivity(u.id, { page_size: 500 })
      .then(r => setActivity(r.data?.results ?? r.data ?? []))
      .catch(() => setActivity([]))
      .finally(() => setLoading(false));
  }, [u.id]);

  const loginDates = activity.map(a => a.timestamp);
  const joinedBS = adToBS(new Date(u.created_at));
  const [actionError, setActionError] = useState("");

  const doAction = async (action) => {
    setActing(true);
    setActionError("");
    try {
      await adminApi.userAction(u.id, action);
      onAction();
      onClose();
    } catch (e) {
      setActionError(e.response?.data?.error || e.response?.data?.detail || "Couldn't complete that action. Please try again.");
    }
    setActing(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-xl rounded-2xl border border-navy-700 bg-navy-900 p-6 max-h-[90vh] overflow-y-auto">
        <div className="mb-5 flex items-start justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-orange-500/15 text-lg font-bold text-orange-400">
              {u.name?.[0]?.toUpperCase() || "U"}
            </div>
            <div>
              <p className="font-bold text-white">{u.name || "—"}</p>
              <p className="text-sm text-navy-400">{u.email}</p>
              <div className="mt-1 flex gap-1">
                {u.is_platform_admin && <Badge label="Admin" color="orange" />}
                {u.is_active ? <Badge label="Active" color="green" /> : <Badge label="Inactive" color="red" />}
                {u.is_verified ? <Badge label="Verified" color="blue" /> : <Badge label="Unverified" color="yellow" />}
              </div>
            </div>
          </div>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>

        <div className="mb-5 grid grid-cols-3 gap-3">
          <div className="rounded-xl border border-navy-800 bg-navy-950 px-3 py-2.5 text-center">
            <p className="text-[10px] text-navy-400">Logins</p>
            <p className="mt-1 text-lg font-bold text-white">{activity.length}</p>
          </div>
          <div className="rounded-xl border border-navy-800 bg-navy-950 px-3 py-2.5 text-center">
            <p className="text-[10px] text-navy-400">Type</p>
            <p className="mt-1 text-sm font-semibold text-orange-400 capitalize">{u.account_type}</p>
          </div>
          <div className="rounded-xl border border-navy-800 bg-navy-950 px-3 py-2.5 text-center">
            <p className="text-[10px] text-navy-400">Joined (BS)</p>
            <p className="mt-1 text-[11px] font-medium text-white">{formatBS(joinedBS, language)}</p>
          </div>
        </div>

        {actionError && (
          <div className="mb-4 flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">
            <AlertTriangle className="h-3.5 w-3.5 shrink-0" /> {actionError}
          </div>
        )}

        {/* Action buttons */}
        <div className="mb-5 flex flex-wrap gap-2">
          {u.is_active ? (
            <button disabled={acting} onClick={() => doAction("deactivate")}
              className="flex items-center gap-1.5 rounded-lg bg-red-500/10 border border-red-500/30 px-3 py-1.5 text-xs font-medium text-red-400 hover:bg-red-500/20 disabled:opacity-50">
              <XCircle className="h-3.5 w-3.5" /> Deactivate
            </button>
          ) : (
            <button disabled={acting} onClick={() => doAction("activate")}
              className="flex items-center gap-1.5 rounded-lg bg-green-500/10 border border-green-500/30 px-3 py-1.5 text-xs font-medium text-green-400 hover:bg-green-500/20 disabled:opacity-50">
              <CheckCircle2 className="h-3.5 w-3.5" /> Activate
            </button>
          )}
          {!u.is_platform_admin ? (
            <button disabled={acting} onClick={() => doAction("make_admin")}
              className="flex items-center gap-1.5 rounded-lg bg-orange-500/10 border border-orange-500/30 px-3 py-1.5 text-xs font-medium text-orange-400 hover:bg-orange-500/20 disabled:opacity-50">
              <Crown className="h-3.5 w-3.5" /> Make Admin
            </button>
          ) : (
            <button disabled={acting} onClick={() => doAction("remove_admin")}
              className="flex items-center gap-1.5 rounded-lg bg-navy-800 border border-navy-700 px-3 py-1.5 text-xs font-medium text-navy-300 hover:bg-navy-700 disabled:opacity-50">
              <ShieldCheck className="h-3.5 w-3.5" /> Remove Admin
            </button>
          )}
        </div>

        {/* Calendar */}
        <div className="rounded-xl border border-navy-800 bg-navy-950 p-4">
          <div className="mb-3 flex items-center gap-2">
            <CalendarDays className="h-4 w-4 text-orange-400" />
            <p className="text-sm font-semibold text-white">Login Activity</p>
          </div>
          {loading ? (
            <p className="py-4 text-center text-xs text-navy-400">Loading...</p>
          ) : (
            <LoginCalendar loginDates={loginDates} lang={language} />
          )}
        </div>

        {activity.length > 0 && (
          <div className="mt-4 space-y-1 max-h-36 overflow-y-auto">
            {activity.slice(0, 10).map(a => {
              const d = new Date(a.timestamp);
              const bs = adToBS(d);
              return (
                <div key={a.id} className="flex items-center justify-between rounded-lg border border-navy-800 bg-navy-950 px-3 py-1.5 text-xs">
                  <span className="text-navy-300">{d.toLocaleString()}</span>
                  <span className="text-orange-300 text-[10px]">{formatBS(bs, language)}</span>
                  <span className={`rounded px-1.5 py-0.5 ${a.success ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"}`}>
                    {a.success ? "✓" : "✗"}
                  </span>
                </div>
              );
            })}
          </div>
        )}

        <div className="mt-4">
          <button onClick={onClose} className="w-full rounded-xl border border-navy-700 py-2.5 text-sm font-medium text-navy-400 hover:bg-navy-800">Close</button>
        </div>
      </div>
    </div>
  );
}

/* ── Announcement Modal ──────────────────────────────────────────────────── */
function AnnouncementModal({ data, onClose, onSaved }) {
  const [form, setForm] = useState({ title: data?.title || "", body: data?.body || "", is_active: data?.is_active ?? true });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const handleSave = async () => {
    if (!form.title.trim() || !form.body.trim()) { setError("Title and body are required."); return; }
    setSaving(true);
    try {
      if (data?.id) {
        await adminApi.updateAnnouncement(data.id, form);
      } else {
        await adminApi.createAnnouncement(form);
      }
      onSaved();
    } catch (e) {
      const data = e.response?.data;
      setError(
        data?.error || data?.detail ||
        (data && typeof data === "object" ? Object.values(data).flat().join(" ") : null) ||
        "Failed to save."
      );
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-lg rounded-2xl border border-navy-700 bg-navy-900 p-6 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-white">{data?.id ? "Edit Announcement" : "New Announcement"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {error && <p className="rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">{error}</p>}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Title *</label>
          <input className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
            value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder="Announcement title..." />
        </div>
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Body *</label>
          <textarea rows={4} className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none resize-none"
            value={form.body} onChange={e => setForm(f => ({ ...f, body: e.target.value }))} placeholder="Announcement content..." />
        </div>
        <div className="flex items-center gap-3">
          <button onClick={() => setForm(f => ({ ...f, is_active: !f.is_active }))}>
            {form.is_active
              ? <ToggleRight className="h-6 w-6 text-green-400" />
              : <ToggleLeft className="h-6 w-6 text-navy-500" />}
          </button>
          <span className="text-sm text-navy-300">{form.is_active ? "Active (visible to users)" : "Inactive (hidden)"}</span>
        </div>
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm">Cancel</button>
          <button disabled={saving} onClick={handleSave} className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 text-sm disabled:opacity-50">
            {saving ? "Saving..." : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Create User Modal ───────────────────────────────────────────────────── */
function CreateUserModal({ onClose, onSaved }) {
  const [form, setForm] = useState({ email: "", name: "", is_platform_admin: false });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const handleSave = async () => {
    if (!form.email.trim()) { setError("Email is required."); return; }
    setSaving(true);
    try {
      await adminApi.createUser(form);
      onSaved();
    } catch (e) {
      setError(e.response?.data?.error || "Failed to create user.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-white">Create New User</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {error && <p className="rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">{error}</p>}
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Email *</label>
          <input type="email" className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
            value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} placeholder="user@example.com" />
        </div>
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Name</label>
          <input className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
            value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="Full name (optional)" />
        </div>
        <div className="flex items-center gap-3">
          <button type="button" onClick={() => setForm(f => ({ ...f, is_platform_admin: !f.is_platform_admin }))}>
            {form.is_platform_admin
              ? <ToggleRight className="h-6 w-6 text-orange-400" />
              : <ToggleLeft className="h-6 w-6 text-navy-500" />}
          </button>
          <span className="text-sm text-navy-300">Platform Admin</span>
        </div>
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm">Cancel</button>
          <button disabled={saving} onClick={handleSave} className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 text-sm disabled:opacity-50">
            {saving ? "Creating..." : "Create User"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Edit Business Modal ─────────────────────────────────────────────────── */
function EditBusinessModal({ biz, onClose, onSaved }) {
  const [form, setForm] = useState({ name: biz.name || "", address: biz.address || "", phone: biz.phone || "", email: biz.email || "" });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const handleSave = async () => {
    setSaving(true);
    try {
      await adminApi.editBusiness(biz.id, form);
      onSaved();
    } catch (e) {
      const data = e.response?.data;
      setError(
        data?.error || data?.detail ||
        (data && typeof data === "object" ? Object.values(data).flat().join(" ") : null) ||
        "Failed to update."
      );
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-white">Edit Business</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {error && <p className="rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">{error}</p>}
        {[
          { key: "name", label: "Business Name" },
          { key: "address", label: "Address" },
          { key: "phone", label: "Phone" },
          { key: "email", label: "Email" },
        ].map(({ key, label }) => (
          <div key={key}>
            <label className="mb-1 block text-xs font-semibold text-navy-400">{label}</label>
            <input className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
              value={form[key]} onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))} />
          </div>
        ))}
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm">Cancel</button>
          <button disabled={saving} onClick={handleSave} className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 text-sm disabled:opacity-50">
            {saving ? "Saving..." : "Save Changes"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Business Data Modal ─────────────────────────────────────────────────── */
function BusinessDataModal({ bizId, onClose }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    adminApi.businessData(bizId)
      .then(r => setData(r.data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [bizId]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{data?.business?.name || "Business Data"}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {loading ? (
          <div className="py-8 text-center text-sm text-navy-400">Loading…</div>
        ) : data ? (
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "Total Sales", value: `Rs. ${data.sales.total.toLocaleString()}`, sub: `${data.sales.count} records`, color: "text-green-400" },
              { label: "Total Purchases", value: `Rs. ${data.purchases.total.toLocaleString()}`, sub: `${data.purchases.count} records`, color: "text-blue-400" },
              { label: "Total Expenses", value: `Rs. ${data.expenses.total.toLocaleString()}`, sub: `${data.expenses.count} records`, color: "text-red-400" },
              { label: "Inventory", value: data.inventory_count, sub: "products", color: "text-orange-400" },
              { label: "Parties", value: data.parties_count, sub: "customers/suppliers", color: "text-purple-400" },
              { label: "Plan", value: data.business.plan, sub: data.business.status, color: "text-yellow-400" },
            ].map(({ label, value, sub, color }) => (
              <div key={label} className="rounded-xl border border-navy-800 bg-navy-950 p-3">
                <p className="text-[10px] text-navy-400 mb-1">{label}</p>
                <p className={`text-lg font-bold ${color}`}>{value}</p>
                <p className="text-[10px] text-navy-500">{sub}</p>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-center text-sm text-navy-400">Could not load data.</p>
        )}
        <button onClick={onClose} className="mt-5 w-full rounded-xl border border-navy-700 py-2.5 text-sm font-medium text-navy-400 hover:bg-navy-800">Close</button>
      </div>
    </div>
  );
}

/* ── Ticket Reply Modal ────────────────────────────────────────────────────── */
function TicketModal({ ticket, onClose, onSaved }) {
  const [reply, setReply] = useState(ticket.admin_reply || "");
  const [ticketStatus, setTicketStatus] = useState(ticket.status || "OPEN");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const handleSave = async () => {
    setSaving(true);
    setError("");
    try {
      await adminApi.updateTicket(ticket.id, { admin_reply: reply, status: ticketStatus });
      onSaved();
    } catch (e) {
      setError(e.response?.data?.error || e.response?.data?.detail || "Couldn't save the reply. Please try again.");
    }
    setSaving(false);
  };

  const statusColors = { OPEN: "text-yellow-400", IN_PROGRESS: "text-blue-400", CLOSED: "text-navy-400" };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-lg rounded-2xl border border-navy-700 bg-navy-900 p-6 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-white">Support Ticket #{ticket.id}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {error && <p className="rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">{error}</p>}
        <div className="rounded-xl border border-navy-800 bg-navy-950 p-4 space-y-2">
          <div className="flex items-center justify-between">
            <p className="text-xs text-navy-400">From: <span className="text-white">{ticket.user_email}</span></p>
            {ticket.business_name && <p className="text-xs text-navy-400">{ticket.business_name}</p>}
          </div>
          <p className="text-sm font-semibold text-white">{ticket.subject}</p>
          <p className="text-sm text-navy-300">{ticket.message}</p>
          <p className="text-[10px] text-navy-500">{new Date(ticket.created_at).toLocaleString()}</p>
        </div>
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Admin Reply</label>
          <textarea rows={3} className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none resize-none"
            value={reply} onChange={e => setReply(e.target.value)} placeholder="Write your reply..." />
        </div>
        <div>
          <label className="mb-1 block text-xs font-semibold text-navy-400">Status</label>
          <select className="w-full rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
            value={ticketStatus} onChange={e => setTicketStatus(e.target.value)}>
            {["OPEN", "IN_PROGRESS", "CLOSED"].map(s => (
              <option key={s} value={s}>{s.replace("_", " ").toUpperCase()}</option>
            ))}
          </select>
        </div>
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-navy-700 text-navy-400 hover:bg-navy-800 text-sm">Cancel</button>
          <button disabled={saving} onClick={handleSave} className="px-4 py-2 rounded-lg bg-orange-500 text-white hover:bg-orange-600 text-sm disabled:opacity-50">
            {saving ? "Saving..." : "Save Reply"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Overview Tab ─────────────────────────────────────────────────────────── */
function OverviewTab({ stats }) {
  if (!stats) return null;
  const cards = [
    { label: "Total Businesses", value: stats.total_businesses, icon: Building2, color: "text-blue-400", bg: "bg-blue-500/10" },
    { label: "Active Businesses", value: stats.active_businesses, icon: CheckCircle2, color: "text-green-400", bg: "bg-green-500/10" },
    { label: "Suspended", value: stats.suspended_businesses, icon: XCircle, color: "text-red-400", bg: "bg-red-500/10" },
    { label: "Premium Plans", value: stats.premium_count, icon: Crown, color: "text-yellow-400", bg: "bg-yellow-500/10" },
    { label: "Total Users", value: stats.total_users, icon: Users, color: "text-orange-400", bg: "bg-orange-500/10" },
    { label: "New This Month", value: stats.new_businesses_this_month ?? stats.new_this_month, icon: TrendingUp, color: "text-purple-400", bg: "bg-purple-500/10" },
    { label: "New Users (Month)", value: stats.new_users_this_month, icon: Users, color: "text-blue-400", bg: "bg-blue-500/10" },
    { label: "Logins (30 days)", value: stats.logins_last_30_days, icon: CalendarDays, color: "text-green-400", bg: "bg-green-500/10" },
  ];
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {cards.map(({ label, value, icon: Icon, color, bg }) => (
        <div key={label} className="rounded-2xl border border-navy-800 bg-navy-900 p-5">
          <div className="flex items-center justify-between mb-3">
            <p className="text-xs text-navy-400">{label}</p>
            <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${bg}`}>
              <Icon className={`h-4 w-4 ${color}`} />
            </div>
          </div>
          <p className="text-2xl font-bold text-white">{value ?? "—"}</p>
        </div>
      ))}
    </div>
  );
}

/* ── Businesses Tab ────────────────────────────────────────────────────────── */
const BIZ_PAGE_SIZE = 50;

function BusinessesTab({ onCountChange }) {
  const [rows, setRows] = useState([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounced(search);
  const [planFilter, setPlanFilter] = useState("ALL");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [confirm, setConfirm] = useState(null);
  const [confirmError, setConfirmError] = useState("");
  const [deletingBiz, setDeletingBiz] = useState(null);
  const [deleteError, setDeleteError] = useState("");
  const [editingBiz, setEditingBiz] = useState(null);
  const [viewDataBiz, setViewDataBiz] = useState(null);
  const [acting, setActing] = useState(false);
  const [inlineError, setInlineError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, page_size: BIZ_PAGE_SIZE };
      if (debouncedSearch) params.search = debouncedSearch;
      if (planFilter !== "ALL") params.plan = planFilter;
      if (statusFilter !== "ALL") params.status = statusFilter;
      const { data } = await adminApi.businesses(params);
      const results = data?.results ?? data ?? [];
      const total = data?.count ?? results.length;
      setRows(results);
      setCount(total);
      onCountChange?.(total);
    } catch {
      setRows([]);
      setCount(0);
    } finally {
      setLoading(false);
    }
  }, [page, debouncedSearch, planFilter, statusFilter]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [debouncedSearch, planFilter, statusFilter]);

  const doAction = async (bizId, action, label) => {
    setActing(true);
    setConfirmError("");
    try {
      await adminApi.businessAction(bizId, action);
      await load();
      setConfirm(null);
    } catch (e) {
      const data = e.response?.data;
      const msg = data?.error || data?.detail || `Couldn't update "${label}". Please try again.`;
      // Instant actions (activate/upgrade/downgrade) have no confirm dialog
      // open to show this in, so fall back to a dedicated banner for them.
      if (confirm) setConfirmError(msg); else setInlineError(msg);
    }
    setActing(false);
  };

  const doDeleteBiz = async () => {
    setActing(true);
    setDeleteError("");
    try {
      await adminApi.deleteBusiness(deletingBiz.id);
      await load();
      setDeletingBiz(null);
    } catch (e) {
      setDeleteError(e.response?.data?.error || e.response?.data?.detail || `Couldn't delete "${deletingBiz.name}". Please try again.`);
    }
    setActing(false);
  };

  return (
    <div className="space-y-4">
      {/* Filters */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative flex-1 max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-navy-500" />
          <input className="w-full rounded-lg bg-navy-800 border border-navy-700 pl-9 pr-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
            placeholder="Search by name or owner..." value={search} onChange={e => setSearch(e.target.value)} />
        </div>
        <div className="flex gap-2">
          <select className="rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-xs text-white focus:border-orange-500 focus:outline-none"
            value={planFilter} onChange={e => setPlanFilter(e.target.value)}>
            <option value="ALL">All Plans</option>
            <option value="FREE">Free</option>
            <option value="PREMIUM">Premium</option>
          </select>
          <select className="rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-xs text-white focus:border-orange-500 focus:outline-none"
            value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
            <option value="ALL">All Status</option>
            <option value="ACTIVE">Active</option>
            <option value="SUSPENDED">Suspended</option>
          </select>
        </div>
      </div>

      {inlineError && (
        <div className="flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">
          <AlertTriangle className="h-3.5 w-3.5 shrink-0" /> {inlineError}
        </div>
      )}

      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
        {loading ? (
          <div className="flex justify-center py-16"><Loader className="h-5 w-5 animate-spin text-orange-500" /></div>
        ) : rows.length === 0 ? (
          <p className="py-8 text-center text-sm text-navy-400">No businesses found</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-navy-800 text-left text-xs text-navy-500">
                  <th className="px-4 py-3 font-medium">Business</th>
                  <th className="px-4 py-3 font-medium">Joined</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium">Plan</th>
                  <th className="px-4 py-3 font-medium text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-navy-800/50">
                {rows.map(biz => (
                  <tr key={biz.id} className="hover:bg-navy-800/30 transition">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-navy-800">
                          <Building2 className="h-4 w-4 text-orange-400" />
                        </div>
                        <div>
                          <p className="font-medium text-white">{biz.name}</p>
                          <p className="text-xs text-navy-400">{biz.owner_name}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-navy-400">{new Date(biz.created_at).toLocaleDateString()}</td>
                    <td className="px-4 py-3"><Badge label={biz.status} color={biz.status === "ACTIVE" ? "green" : "red"} /></td>
                    <td className="px-4 py-3"><Badge label={biz.plan} color={biz.plan === "PREMIUM" ? "yellow" : "gray"} /></td>
                    <td className="px-4 py-3">
                      <div className="flex items-center justify-end gap-1.5 flex-wrap">
                        {biz.status === "ACTIVE" ? (
                          <button disabled={acting} onClick={() => setConfirm({ bizId: biz.id, action: "suspend", label: biz.name })}
                            className="flex items-center gap-1 rounded-lg border border-red-500/30 px-2 py-1 text-xs text-red-400 hover:bg-red-500/10 disabled:opacity-50">
                            <ToggleRight className="h-3.5 w-3.5" /> Suspend
                          </button>
                        ) : (
                          <button disabled={acting} onClick={() => doAction(biz.id, "activate", biz.name)}
                            className="flex items-center gap-1 rounded-lg border border-green-500/30 px-2 py-1 text-xs text-green-400 hover:bg-green-500/10 disabled:opacity-50">
                            <ToggleLeft className="h-3.5 w-3.5" /> Activate
                          </button>
                        )}
                        {biz.plan === "FREE" ? (
                          <button disabled={acting} onClick={() => doAction(biz.id, "upgrade", biz.name)}
                            className="flex items-center gap-1 rounded-lg border border-yellow-500/30 px-2 py-1 text-xs text-yellow-400 hover:bg-yellow-500/10 disabled:opacity-50">
                            <Crown className="h-3.5 w-3.5" /> Upgrade
                          </button>
                        ) : (
                          <button disabled={acting} onClick={() => doAction(biz.id, "downgrade", biz.name)}
                            className="flex items-center gap-1 rounded-lg border border-navy-600 px-2 py-1 text-xs text-navy-400 hover:bg-navy-800 disabled:opacity-50">
                            Downgrade
                          </button>
                        )}
                        <button onClick={() => setViewDataBiz(biz.id)}
                          className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-blue-500/40 hover:text-blue-400 transition" title="View Data">
                          <TrendingUp className="h-3.5 w-3.5" />
                        </button>
                        <button onClick={() => setEditingBiz(biz)}
                          className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-orange-500/40 hover:text-orange-400 transition" title="Edit">
                          <Edit2 className="h-3.5 w-3.5" />
                        </button>
                        <button onClick={() => setDeletingBiz(biz)}
                          className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-red-500/40 hover:text-red-400 transition" title="Delete">
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!loading && rows.length > 0 && (
          <PaginationFooter page={page} pageSize={BIZ_PAGE_SIZE} count={count} onPageChange={setPage} />
        )}
      </div>

      {confirm && (
        <ConfirmDialog
          title={`Suspend "${confirm.label}"?`}
          body="The business and its users will lose access until re-activated."
          error={confirmError}
          busy={acting}
          onConfirm={() => doAction(confirm.bizId, confirm.action, confirm.label)}
          onCancel={() => { setConfirm(null); setConfirmError(""); }}
          dangerous
        />
      )}
      {deletingBiz && (
        <ConfirmDialog
          title={`Permanently delete "${deletingBiz.name}"?`}
          body="All business data (sales, inventory, expenses, etc.) will be deleted forever."
          error={deleteError}
          busy={acting}
          onConfirm={doDeleteBiz}
          onCancel={() => { setDeletingBiz(null); setDeleteError(""); }}
          dangerous
        />
      )}
      {editingBiz && (
        <EditBusinessModal
          biz={editingBiz}
          onClose={() => setEditingBiz(null)}
          onSaved={() => { setEditingBiz(null); load(); }}
        />
      )}
      {viewDataBiz && (
        <BusinessDataModal bizId={viewDataBiz} onClose={() => setViewDataBiz(null)} />
      )}
    </div>
  );
}

/* ── Users Tab ────────────────────────────────────────────────────────────── */
const USER_PAGE_SIZE = 50;

function UsersTab({ onCountChange }) {
  const [rows, setRows] = useState([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounced(search);
  const [selectedUser, setSelectedUser] = useState(null);
  const [showCreate, setShowCreate] = useState(false);
  const [deletingUser, setDeletingUser] = useState(null);
  const [deleteError, setDeleteError] = useState("");
  const [acting, setActing] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, page_size: USER_PAGE_SIZE };
      if (debouncedSearch) params.search = debouncedSearch;
      const { data } = await adminApi.users(params);
      const results = data?.results ?? data ?? [];
      const total = data?.count ?? results.length;
      setRows(results);
      setCount(total);
      onCountChange?.(total);
    } catch {
      setRows([]);
      setCount(0);
    } finally {
      setLoading(false);
    }
  }, [page, debouncedSearch]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [debouncedSearch]);

  const doDelete = async () => {
    setActing(true);
    setDeleteError("");
    try {
      await adminApi.deleteUser(deletingUser.id);
      await load();
      setDeletingUser(null);
    } catch (e) {
      setDeleteError(e.response?.data?.error || e.response?.data?.detail || "Couldn't delete this user. Please try again.");
    }
    setActing(false);
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative max-w-xs flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-navy-500" />
          <input className="w-full rounded-lg bg-navy-800 border border-navy-700 pl-9 pr-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
            placeholder="Search by name or email..." value={search} onChange={e => setSearch(e.target.value)} />
        </div>
        <button onClick={() => setShowCreate(true)}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600">
          <Plus className="h-4 w-4" /> New User
        </button>
      </div>

      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
        {loading ? (
          <div className="flex justify-center py-16"><Loader className="h-5 w-5 animate-spin text-orange-500" /></div>
        ) : rows.length === 0 ? (
          <p className="py-8 text-center text-sm text-navy-400">No users found</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-navy-800 text-left text-xs text-navy-500">
                  <th className="px-4 py-3 font-medium">User</th>
                  <th className="px-4 py-3 font-medium">Type</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-navy-800/50">
                {rows.map(u => (
                  <tr key={u.id} className="hover:bg-navy-800/30 transition">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-navy-800 text-sm font-bold text-white">
                          {u.name?.[0]?.toUpperCase() || "U"}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <p className="font-medium text-white">{u.name || "—"}</p>
                            {u.is_platform_admin && <Badge label="Admin" color="orange" />}
                          </div>
                          <p className="text-xs text-navy-400">{u.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-navy-300 capitalize">{u.account_type}</td>
                    <td className="px-4 py-3"><Badge label={u.is_active ? "Active" : "Inactive"} color={u.is_active ? "green" : "red"} /></td>
                    <td className="px-4 py-3">
                      <div className="flex items-center justify-end gap-2">
                        <button onClick={() => setSelectedUser(u)}
                          className="flex items-center gap-1.5 rounded-lg border border-navy-700 px-2.5 py-1.5 text-xs text-navy-300 hover:border-orange-500/40 hover:text-orange-400 transition">
                          <CalendarDays className="h-3 w-3" /> Details
                        </button>
                        <button onClick={() => setDeletingUser(u)}
                          className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-red-500/40 hover:text-red-400 transition">
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {!loading && rows.length > 0 && (
          <PaginationFooter page={page} pageSize={USER_PAGE_SIZE} count={count} onPageChange={setPage} />
        )}
      </div>

      {selectedUser && (
        <UserDetailModal
          user={selectedUser}
          onClose={() => setSelectedUser(null)}
          onAction={() => { setSelectedUser(null); load(); }}
        />
      )}
      {showCreate && (
        <CreateUserModal
          onClose={() => setShowCreate(false)}
          onSaved={() => { setShowCreate(false); load(); }}
        />
      )}
      {deletingUser && (
        <ConfirmDialog
          title={`Delete "${deletingUser.name || deletingUser.email}"?`}
          body="This will permanently delete the user and all their data. This cannot be undone."
          error={deleteError}
          busy={acting}
          onConfirm={doDelete}
          onCancel={() => { setDeletingUser(null); setDeleteError(""); }}
          dangerous
        />
      )}
    </div>
  );
}

/* ── Announcements Tab ──────────────────────────────────────────────────── */
function AnnouncementsTab({ announcements, onRefresh }) {
  const [showModal, setShowModal] = useState(false);
  const [editAnn, setEditAnn] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [confirmError, setConfirmError] = useState("");
  const [acting, setActing] = useState(false);
  const [toggleError, setToggleError] = useState("");

  const doDelete = async (id) => {
    setActing(true);
    setConfirmError("");
    try {
      await adminApi.deleteAnnouncement(id);
      onRefresh();
      setConfirm(null);
    } catch (e) {
      setConfirmError(e.response?.data?.error || e.response?.data?.detail || "Couldn't delete this announcement. Please try again.");
    }
    setActing(false);
  };

  const doToggle = async (ann) => {
    setToggleError("");
    try {
      await adminApi.updateAnnouncement(ann.id, { ...ann, is_active: !ann.is_active });
      onRefresh();
    } catch (e) {
      setToggleError(e.response?.data?.error || e.response?.data?.detail || `Couldn't ${ann.is_active ? "deactivate" : "activate"} "${ann.title}".`);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3">
        {toggleError ? (
          <p className="text-xs text-red-400">{toggleError}</p>
        ) : <span />}
        <button onClick={() => { setEditAnn(null); setShowModal(true); }}
          className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600">
          <Plus className="h-4 w-4" /> New Announcement
        </button>
      </div>

      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
        {announcements.length === 0 ? (
          <div className="py-12 text-center">
            <Bell className="mx-auto h-8 w-8 text-navy-600 mb-2" />
            <p className="text-sm text-navy-400">No announcements yet</p>
          </div>
        ) : (
          <div className="divide-y divide-navy-800/50">
            {announcements.map(ann => (
              <div key={ann.id} className="px-4 py-4 hover:bg-navy-800/30 transition">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <p className="text-sm font-semibold text-white truncate">{ann.title}</p>
                      <Badge label={ann.is_active ? "Active" : "Inactive"} color={ann.is_active ? "green" : "gray"} />
                    </div>
                    <p className="text-xs text-navy-400 line-clamp-2">{ann.body}</p>
                    <p className="mt-1 text-[10px] text-navy-500">{new Date(ann.created_at).toLocaleString()}</p>
                  </div>
                  <div className="flex shrink-0 gap-1">
                    <button onClick={() => doToggle(ann)} title={ann.is_active ? "Deactivate" : "Activate"}
                      className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-orange-500/40 hover:text-orange-400">
                      {ann.is_active ? <ToggleRight className="h-4 w-4 text-green-400" /> : <ToggleLeft className="h-4 w-4" />}
                    </button>
                    <button onClick={() => { setEditAnn(ann); setShowModal(true); }}
                      className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-orange-500/40 hover:text-orange-400">
                      <Edit2 className="h-4 w-4" />
                    </button>
                    <button disabled={acting} onClick={() => setConfirm(ann.id)}
                      className="rounded-lg border border-navy-700 p-1.5 text-navy-400 hover:border-red-500/40 hover:text-red-400 disabled:opacity-50">
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showModal && (
        <AnnouncementModal
          data={editAnn}
          onClose={() => { setShowModal(false); setEditAnn(null); }}
          onSaved={() => { setShowModal(false); setEditAnn(null); onRefresh(); }}
        />
      )}
      {confirm && (
        <ConfirmDialog
          title="Delete announcement?"
          body="This will permanently delete the announcement."
          error={confirmError}
          busy={acting}
          onConfirm={() => doDelete(confirm)}
          onCancel={() => { setConfirm(null); setConfirmError(""); }}
          dangerous
        />
      )}
    </div>
  );
}

/* ── Feature Management Tab ──────────────────────────────────────────────────
   Master switch for every app module — enforced on the backend for both
   Desktop (React) and Mobile (Flutter), not just hidden in this UI. See
   backend bewosai/permissions.py::require_feature. */
function FeaturesTab({ features, onRefresh }) {
  const [busyKey, setBusyKey] = useState(null);
  const [error, setError] = useState("");

  const toggle = async (feature, field) => {
    setBusyKey(feature.key + field);
    setError("");
    try {
      await adminApi.toggleFeature(feature.key, { [field]: !feature[field] });
      onRefresh();
    } catch (e) {
      const data = e.response?.data;
      setError(
        data?.error || data?.detail ||
        (data && typeof data === "object" ? Object.values(data).flat().join(" ") : null) ||
        `Couldn't update "${feature.name}". Please try again.`
      );
    }
    setBusyKey(null);
  };

  const availableTo = (f) => {
    if (!f.enabled) return "—";
    return f.premium_only ? "Premium" : "All businesses";
  };

  return (
    <div className="space-y-4">
      <p className="text-xs text-navy-500">
        Disabling a feature here overrides every staff permission underneath it — nobody in any
        business can use it, on Desktop or Mobile, until it's switched back on.
      </p>
      {error && (
        <div className="flex items-center gap-2 rounded-lg bg-red-500/10 px-3 py-2 text-xs text-red-400">
          <AlertTriangle className="h-3.5 w-3.5 shrink-0" /> {error}
        </div>
      )}
      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-navy-800 text-left text-xs text-navy-500">
              <th className="px-4 py-3 font-medium">Feature</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Available To</th>
              <th className="px-4 py-3 font-medium text-center">Desktop</th>
              <th className="px-4 py-3 font-medium text-center">Mobile</th>
              <th className="px-4 py-3 font-medium text-center">Premium Only</th>
              <th className="px-4 py-3 font-medium text-right">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-navy-800/50">
            {features.map((f) => (
              <tr key={f.key} className="hover:bg-navy-800/30 transition">
                <td className="px-4 py-3">
                  <p className="font-semibold text-white">{f.name}</p>
                  <p className="text-[11px] text-navy-500">{f.key}</p>
                </td>
                <td className="px-4 py-3">
                  <Badge label={f.enabled ? "Enabled" : "Disabled"} color={f.enabled ? "green" : "red"} />
                </td>
                <td className="px-4 py-3 text-navy-300">{availableTo(f)}</td>
                <td className="px-4 py-3 text-center">
                  <button disabled={busyKey === f.key + "desktop_enabled"} onClick={() => toggle(f, "desktop_enabled")}
                    title={f.desktop_enabled ? "Disable on Desktop" : "Enable on Desktop"}
                    className="inline-flex items-center gap-1 text-navy-400 hover:text-orange-400 disabled:opacity-50">
                    <Monitor className="h-3.5 w-3.5" />
                    {f.desktop_enabled ? <ToggleRight className="h-4 w-4 text-green-400" /> : <ToggleLeft className="h-4 w-4" />}
                  </button>
                </td>
                <td className="px-4 py-3 text-center">
                  <button disabled={busyKey === f.key + "mobile_enabled"} onClick={() => toggle(f, "mobile_enabled")}
                    title={f.mobile_enabled ? "Disable on Mobile" : "Enable on Mobile"}
                    className="inline-flex items-center gap-1 text-navy-400 hover:text-orange-400 disabled:opacity-50">
                    <Smartphone className="h-3.5 w-3.5" />
                    {f.mobile_enabled ? <ToggleRight className="h-4 w-4 text-green-400" /> : <ToggleLeft className="h-4 w-4" />}
                  </button>
                </td>
                <td className="px-4 py-3 text-center">
                  <button disabled={busyKey === f.key + "premium_only"} onClick={() => toggle(f, "premium_only")}
                    title={f.premium_only ? "Make available to all plans" : "Restrict to Premium plan"}
                    className="text-navy-400 hover:text-orange-400 disabled:opacity-50">
                    {f.premium_only ? <Crown className="h-4 w-4 text-yellow-400" /> : <Crown className="h-4 w-4" />}
                  </button>
                </td>
                <td className="px-4 py-3 text-right">
                  <button disabled={busyKey === f.key + "enabled"} onClick={() => toggle(f, "enabled")}
                    className={`rounded-lg border px-3 py-1.5 text-xs font-semibold transition disabled:opacity-50 ${
                      f.enabled
                        ? "border-red-500/30 text-red-400 hover:bg-red-500/10"
                        : "border-green-500/30 text-green-400 hover:bg-green-500/10"
                    }`}>
                    {f.enabled ? "Disable" : "Enable"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/* ── Tickets Tab ──────────────────────────────────────────────────────────── */
function TicketsTab({ tickets, onRefresh }) {
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [selectedTicket, setSelectedTicket] = useState(null);

  const statusColors = { OPEN: "yellow", IN_PROGRESS: "blue", CLOSED: "gray" };

  const filtered = tickets.filter(t =>
    statusFilter === "ALL" || t.status === statusFilter
  );

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        {["ALL", "OPEN", "IN_PROGRESS", "CLOSED"].map(s => (
          <button key={s} onClick={() => setStatusFilter(s)}
            className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${statusFilter === s ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white border border-navy-700"}`}>
            {s === "ALL" ? "All" : s.replace("_", " ").toUpperCase()}
          </button>
        ))}
      </div>

      <div className="rounded-xl border border-navy-800 bg-navy-900 overflow-hidden">
        {filtered.length === 0 ? (
          <div className="py-12 text-center">
            <MessageSquare className="mx-auto h-8 w-8 text-navy-600 mb-2" />
            <p className="text-sm text-navy-400">No tickets found</p>
          </div>
        ) : (
          <div className="divide-y divide-navy-800/50">
            {filtered.map(ticket => (
              <div key={ticket.id} className="flex items-center justify-between px-4 py-4 hover:bg-navy-800/30 transition">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <Badge label={ticket.status?.replace("_", " ").toUpperCase()} color={statusColors[ticket.status] || "gray"} />
                    <p className="text-sm font-medium text-white truncate">{ticket.subject}</p>
                  </div>
                  <p className="text-xs text-navy-400">{ticket.user_email} · {new Date(ticket.created_at).toLocaleDateString()}</p>
                  {ticket.admin_reply && (
                    <p className="mt-1 text-xs text-green-400 truncate">↳ {ticket.admin_reply}</p>
                  )}
                </div>
                <button onClick={() => setSelectedTicket(ticket)}
                  className="ml-3 shrink-0 flex items-center gap-1.5 rounded-lg border border-navy-700 px-2.5 py-1.5 text-xs text-navy-300 hover:border-orange-500/40 hover:text-orange-400 transition">
                  <MessageSquare className="h-3 w-3" /> Reply
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedTicket && (
        <TicketModal
          ticket={selectedTicket}
          onClose={() => setSelectedTicket(null)}
          onSaved={() => { setSelectedTicket(null); onRefresh(); }}
        />
      )}
    </div>
  );
}

/* ── Main SuperAdminPage ──────────────────────────────────────────────────── */
export default function SuperAdminPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [stats, setStats] = useState(null);
  // Full, unpaginated business list — only ever used to power the business
  // search picker in "Generate License" (LicensesTab), which needs to find
  // any business by name/owner, not just whatever's on the Businesses tab's
  // current page. The Businesses tab itself fetches its own paginated data.
  const [businessesFull, setBusinessesFull] = useState([]);
  const [businessCount, setBusinessCount] = useState(null);
  const [userCount, setUserCount] = useState(null);
  const [announcements, setAnnouncements] = useState([]);
  const [tickets, setTickets] = useState([]);
  const [featureList, setFeatureList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [tab, setTab] = useState("overview");

  const load = async (showSpinner = true) => {
    if (showSpinner) setLoading(true); else setRefreshing(true);
    try {
      const [s, b, a, tk, f] = await Promise.allSettled([
        adminApi.stats(),
        adminApi.businesses({ page_size: 1000 }),
        adminApi.announcements({ page_size: 1000 }),
        adminApi.tickets({ page_size: 1000 }),
        adminApi.features(),
      ]);
      if (s.status === "fulfilled") setStats(s.value.data);
      if (b.status === "fulfilled") {
        const results = b.value.data?.results ?? b.value.data ?? [];
        setBusinessesFull(results);
        setBusinessCount((c) => c ?? (b.value.data?.count ?? results.length));
      }
      if (a.status === "fulfilled") setAnnouncements(a.value.data?.results ?? a.value.data ?? []);
      if (tk.status === "fulfilled") setTickets(tk.value.data?.results ?? tk.value.data ?? []);
      if (f.status === "fulfilled") setFeatureList(f.value.data?.results ?? f.value.data ?? []);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    if (!user?.is_platform_admin) { navigate("/dashboard"); return; }
    load();
  }, [user]);

  const openTicketCount = tickets.filter(t => t.status === "OPEN").length;

  const navSections = [
    {
      heading: null,
      items: [{ id: "overview", label: "Dashboard", icon: LayoutDashboard }],
    },
    {
      heading: "Account Management",
      items: [
        { id: "businesses", label: "Businesses", count: businessCount, icon: Building2 },
        { id: "users", label: "Users", count: userCount, icon: Users },
      ],
    },
    {
      heading: "Access Control",
      items: [
        { id: "features", label: "Feature Management", icon: SlidersHorizontal },
        { id: "licenses", label: "Licenses", icon: KeyRound },
      ],
    },
    {
      heading: "Communication",
      items: [
        { id: "announcements", label: "Announcements", icon: Bell },
        { id: "tickets", label: "Support Tickets", count: openTicketCount || null, icon: MessageSquare },
      ],
    },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <ShieldCheck className="h-5 w-5 text-orange-500" /> Super Admin
          </h1>
          <p className="text-sm text-navy-500 mt-0.5">Platform management console</p>
        </div>
        <button onClick={() => load(false)} disabled={refreshing}
          className="flex items-center gap-2 rounded-xl border border-navy-700 px-3 py-2 text-xs text-navy-400 hover:bg-navy-800 disabled:opacity-50">
          <RefreshCw className={`h-3.5 w-3.5 ${refreshing ? "animate-spin" : ""}`} />
          {refreshing ? "Refreshing..." : "Refresh"}
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : (
        <div className="flex flex-col gap-6 lg:flex-row">
          {/* Sidebar nav */}
          <nav className="flex gap-1 overflow-x-auto rounded-xl border border-navy-800 bg-navy-900 p-2 lg:w-56 lg:shrink-0 lg:flex-col lg:overflow-visible">
            {navSections.map((section, si) => (
              <div key={si} className="lg:w-full">
                {section.heading && (
                  <p className="hidden px-3 pb-1.5 pt-3 text-[10px] font-bold uppercase tracking-wider text-navy-600 lg:block first:pt-1">
                    {section.heading}
                  </p>
                )}
                <div className="flex gap-1 lg:flex-col">
                  {section.items.map(({ id, label, count, icon: Icon }) => (
                    <button key={id} onClick={() => setTab(id)}
                      className={`flex shrink-0 items-center gap-2 rounded-lg px-3 py-2 text-left text-xs font-semibold transition lg:w-full ${
                        tab === id ? "bg-orange-500 text-white" : "text-navy-400 hover:bg-navy-800 hover:text-white"
                      }`}>
                      <Icon className="h-3.5 w-3.5 shrink-0" />
                      <span className="flex-1 whitespace-nowrap">{label}</span>
                      {count != null && (
                        <span className={`rounded-full px-1.5 py-0.5 text-[10px] ${tab === id ? "bg-white/20" : "bg-navy-800 text-navy-400"}`}>
                          {count}
                        </span>
                      )}
                    </button>
                  ))}
                </div>
              </div>
            ))}
          </nav>

          {/* Content */}
          <div className="min-w-0 flex-1">
            {tab === "overview" && <OverviewTab stats={stats} />}
            {tab === "businesses" && <BusinessesTab onCountChange={setBusinessCount} />}
            {tab === "users" && <UsersTab onCountChange={setUserCount} />}
            {tab === "features" && <FeaturesTab features={featureList} onRefresh={() => load(false)} />}
            {tab === "licenses" && <LicensesTab businesses={businessesFull} />}
            {tab === "announcements" && <AnnouncementsTab announcements={announcements} onRefresh={() => load(false)} />}
            {tab === "tickets" && <TicketsTab tickets={tickets} onRefresh={() => load(false)} />}
          </div>
        </div>
      )}
    </div>
  );
}
