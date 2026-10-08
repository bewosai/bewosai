import { useState, useEffect } from "react";
import { useAuth } from "../context/AuthContext";
import { useTranslation } from "../utils/translations";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { auth as authApi } from "../api";
import {
  UserCheck, Plus, X, Crown, Check, Edit2, Trash2, Search, Link2, Copy, Share2, MessageCircle, Send, Smartphone,
  RefreshCw, AlertCircle, History, ChevronLeft, ChevronRight, FilePlus, FilePen, FileX, Clock, Mail,
} from "lucide-react";
import ConfirmDialog from "../components/common/ConfirmDialog";
import {
  ACTIONS, MODULES, MODULE_LABELS, ROLES, defaultPermissions, fullMatrix, inviteMessage, roleLabel, staffInviteUrl,
} from "../utils/staffRoles";

// Old-style bearer login link — only staff added before email invitations have one.
function staffLoginUrl(token) {
  return `${window.location.origin}/staff-login/${token}`;
}

const ACTION_LABELS = { view: "View", create: "Add", edit: "Edit", delete: "Delete" };
const isPhone = () => /Android|iPhone|iPad|iPod/i.test(navigator.userAgent || "");

function PermissionMatrix({ permissions, onChange, readonly }) {
  const matrix = fullMatrix(permissions);

  const toggle = (mod, action) => {
    if (readonly) return;
    const row = { ...matrix[mod], [action]: !matrix[mod][action] };
    // Can't add/edit/delete what you can't see; seeing nothing means nothing else.
    if (action !== "view" && row[action]) row.view = true;
    if (action === "view" && !row.view) ACTIONS.forEach((a) => { row[a] = false; });
    onChange({ ...matrix, [mod]: row });
  };

  const allInRow = (mod) => ACTIONS.every((a) => matrix[mod][a]);
  const toggleRow = (mod) => {
    if (readonly) return;
    const value = !allInRow(mod);
    onChange({ ...matrix, [mod]: Object.fromEntries(ACTIONS.map((a) => [a, value])) });
  };

  const ON = {
    orange: "border-orange-500 bg-orange-500/20 text-orange-300",
    blue: "border-blue-500 bg-blue-500/20 text-blue-300",
  };
  const box = (on, color) =>
    `mx-auto flex h-7 w-7 items-center justify-center rounded-lg border transition ${
      on ? ON[color] : "border-navy-600 bg-navy-950 text-transparent"
    } ${readonly ? "cursor-default" : "hover:border-orange-400"}`;

  return (
    <div className="overflow-x-auto rounded-xl border border-navy-800">
      <table className="w-full min-w-[420px] text-sm">
        <thead>
          <tr className="border-b border-navy-800 bg-navy-900">
            <th scope="col" className="px-3 py-2.5 text-left font-semibold text-navy-200">Section</th>
            {ACTIONS.map((a) => (
              <th key={a} scope="col" className="px-2 py-2.5 text-center font-semibold text-navy-200">{ACTION_LABELS[a]}</th>
            ))}
            <th scope="col" className="px-2 py-2.5 text-center font-semibold text-navy-200">All</th>
          </tr>
        </thead>
        <tbody>
          {MODULES.map((mod) => (
            <tr key={mod} className="border-b border-navy-800/50 last:border-0">
              <th scope="row" className="px-3 py-2 text-left font-medium text-white">{MODULE_LABELS[mod]}</th>
              {ACTIONS.map((action) => (
                <td key={action} className="px-2 py-1.5 text-center">
                  <button
                    type="button" onClick={() => toggle(mod, action)} disabled={readonly}
                    aria-label={`${MODULE_LABELS[mod]}: ${ACTION_LABELS[action]}`} aria-pressed={matrix[mod][action]}
                    className={box(matrix[mod][action], "orange")}
                  >
                    <Check className="h-4 w-4" />
                  </button>
                </td>
              ))}
              <td className="px-2 py-1.5 text-center">
                <button
                  type="button" onClick={() => toggleRow(mod)} disabled={readonly}
                  aria-label={`${MODULE_LABELS[mod]}: all`} aria-pressed={allInRow(mod)}
                  className={box(allInRow(mod), "blue")}
                >
                  <Check className="h-4 w-4" />
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function RolePicker({ value, onChange }) {
  return (
    <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
      {ROLES.map((r) => {
        const selected = value === r.key;
        return (
          <button
            key={r.key} type="button" onClick={() => onChange(r.key)} aria-pressed={selected}
            className={`rounded-xl border px-3 py-2.5 text-left transition ${
              selected ? "border-orange-500 bg-orange-500/10" : "border-navy-700 bg-navy-950 hover:border-navy-500"
            }`}
          >
            <span className="flex items-center justify-between gap-2">
              <span className="text-sm font-semibold text-white">{r.label}</span>
              {selected && <Check className="h-4 w-4 shrink-0 text-orange-400" />}
            </span>
            <span className="mt-0.5 block text-xs leading-snug text-navy-300">{r.summary}</span>
          </button>
        );
      })}
    </div>
  );
}

/* ─── The invitation link with every way to send it. ─── */
function InviteSharePanel({ name, businessName, token }) {
  const [copied, setCopied] = useState(false);
  const url = staffInviteUrl(token);
  const message = inviteMessage(name, businessName, url);
  const text = encodeURIComponent(message);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard can be blocked — the link is still selectable in the box.
    }
  };
  const more = async () => {
    try { await navigator.share({ title: "Bewosai invitation", text: message }); } catch { /* closed */ }
  };

  const shareBtn = "flex items-center justify-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-3 text-sm font-semibold text-white transition hover:border-orange-500/60";
  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5">
        <Link2 className="h-4 w-4 shrink-0 text-navy-400" />
        <input
          readOnly value={url} onFocus={(e) => e.target.select()} aria-label="Invitation link"
          className="min-w-0 flex-1 bg-transparent text-sm text-navy-100 outline-none"
        />
        <button type="button" onClick={copy}
          className="flex shrink-0 items-center gap-1 rounded-lg bg-orange-500 px-3 py-2 text-sm font-semibold text-white transition hover:bg-orange-400">
          <Copy className="h-4 w-4" /> {copied ? "Copied!" : "Copy"}
        </button>
      </div>
      <div className="grid grid-cols-2 gap-2">
        <a className={shareBtn} href={`https://wa.me/?text=${text}`} target="_blank" rel="noreferrer">
          <MessageCircle className="h-4 w-4 text-green-400" /> WhatsApp
        </a>
        <a className={shareBtn} href={`sms:?&body=${text}`}>
          <Smartphone className="h-4 w-4 text-blue-300" /> SMS
        </a>
        {isPhone() && (
          <a className={shareBtn} href={`fb-messenger://share/?link=${encodeURIComponent(url)}`}>
            <Send className="h-4 w-4 text-sky-300" /> Messenger
          </a>
        )}
        <a className={shareBtn} href={`mailto:?subject=${encodeURIComponent("Bewosai staff invitation")}&body=${text}`}>
          <Mail className="h-4 w-4 text-orange-300" /> Email
        </a>
        {typeof navigator.share === "function" && (
          <button type="button" className={shareBtn} onClick={more}>
            <Share2 className="h-4 w-4" /> More…
          </button>
        )}
      </div>
      <p className="flex items-start gap-2 rounded-xl border border-blue-500/20 bg-blue-500/5 px-3 py-2.5 text-xs leading-relaxed text-blue-200">
        <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
        They open the link, verify their email with a code and accept. It works once and expires in 7 days.
      </p>
    </div>
  );
}

function Modal({ title, subtitle, onClose, wide, children }) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 sm:items-center sm:p-4" role="dialog" aria-modal="true">
      <div className={`max-h-[92vh] w-full overflow-y-auto rounded-t-2xl border border-navy-700 bg-navy-900 p-5 sm:rounded-2xl sm:p-6 ${wide ? "sm:max-w-2xl" : "sm:max-w-lg"}`}>
        <div className="mb-4 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 className="text-lg font-bold text-white">{title}</h2>
            {subtitle && <p className="mt-0.5 text-sm text-navy-300">{subtitle}</p>}
          </div>
          <button onClick={onClose} aria-label="Close" className="-m-2 rounded-lg p-2 text-navy-300 hover:bg-navy-800 hover:text-white">
            <X className="h-5 w-5" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function InviteModal({ businessId, businessName, onClose, onSaved }) {
  const [form, setForm] = useState({ name: "", email: "", role: "SALESPERSON" });
  const [permissions, setPermissions] = useState(defaultPermissions("SALESPERSON"));
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const [created, setCreated] = useState(null);

  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-3 text-base text-white outline-none placeholder:text-navy-500 focus:border-orange-500";

  const pickRole = (role) => {
    setForm((f) => ({ ...f, role }));
    setPermissions(defaultPermissions(role));
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setErr("Enter the staff member's name."); return; }
    setSaving(true);
    setErr("");
    try {
      const { data } = await authApi.inviteStaff(businessId, { ...form, email: form.email.trim(), permissions });
      setCreated(data);
    } catch (er) {
      const data = er.response?.data;
      setErr(data?.error || data?.name?.[0] || data?.email?.[0] || data?.detail || "Couldn't create the invitation.");
    } finally { setSaving(false); }
  };

  if (created) {
    return (
      <Modal title="Staff added — send the invitation" subtitle={`${created.name} · ${created.role_label}`} onClose={onSaved}>
        <InviteSharePanel name={created.name} businessName={businessName} token={created.token} />
        <PrimaryButton type="button" className="mt-4 w-full justify-center" onClick={onSaved}>Done</PrimaryButton>
      </Modal>
    );
  }

  return (
    <Modal title="Add New Staff" subtitle="Choose a role, adjust what they can do, then send them the invitation." onClose={onClose} wide>
      {err && <p role="alert" className="mb-4 rounded-xl bg-red-500/10 px-3 py-2.5 text-sm text-red-300">{err}</p>}
      <form onSubmit={submit} className="space-y-4">
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="block">
            <span className="mb-1.5 block text-sm font-semibold text-white">Staff name *</span>
            <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="e.g. Ram Sharma" className={field} />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-sm font-semibold text-white">Their email <span className="font-normal text-navy-400">(optional)</span></span>
            <input type="email" inputMode="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="ram@gmail.com" className={field} />
          </label>
        </div>
        <p className="-mt-2 text-xs text-navy-400">If you add an email, only that email can accept the invitation.</p>

        <div>
          <p className="mb-2 text-sm font-semibold text-white">Role</p>
          <RolePicker value={form.role} onChange={pickRole} />
        </div>

        <div>
          <p className="text-sm font-semibold text-white">Manage permissions</p>
          <p className="mb-2 text-xs text-navy-400">Set by the role — tick or untick anything. You can change it any time.</p>
          <PermissionMatrix permissions={permissions} onChange={setPermissions} readonly={false} />
        </div>

        <div className="flex flex-col-reverse gap-2 pt-1 sm:flex-row">
          <PrimaryButton type="button" variant="outline" className="justify-center sm:w-auto" onClick={onClose}>Cancel</PrimaryButton>
          <PrimaryButton type="submit" className="flex-1 justify-center" disabled={saving}>
            {saving ? "Saving…" : "Save & create invitation"}
          </PrimaryButton>
        </div>
      </form>
    </Modal>
  );
}

function LegacyLinkModal({ businessId, member, onClose, onUpdated }) {
  const [current, setCurrent] = useState(member);
  const [regenerating, setRegenerating] = useState(false);
  const [copied, setCopied] = useState(false);
  const [err, setErr] = useState("");

  const regenerate = async () => {
    setRegenerating(true);
    setErr("");
    try {
      const { data } = await authApi.regenerateStaffLink(businessId, member.id);
      setCurrent(data);
      onUpdated?.(data);
    } catch (er) {
      setErr(er.response?.data?.message || er.response?.data?.detail || "Couldn't make a new link.");
    } finally { setRegenerating(false); }
  };
  const url = current.login_token ? staffLoginUrl(current.login_token) : "";

  return (
    <Modal title="Old login link" subtitle={current.user_name} onClose={onClose}>
      {err && <p className="mb-3 rounded-xl bg-red-500/10 px-3 py-2.5 text-sm text-red-300">{err}</p>}
      <p className="mb-3 rounded-xl border border-amber-500/20 bg-amber-500/5 px-3 py-2.5 text-sm leading-relaxed text-amber-200">
        This person was added before email invitations. Anyone with this link can sign in as them.
        For better security, remove them and send a new email invitation.
      </p>
      {url && (
        <div className="mb-3 flex items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5">
          <input readOnly value={url} onFocus={(e) => e.target.select()} className="min-w-0 flex-1 bg-transparent text-sm text-navy-100 outline-none" />
          <button type="button" className="shrink-0 rounded-lg bg-orange-500 px-3 py-2 text-sm font-semibold text-white"
            onClick={async () => { try { await navigator.clipboard.writeText(url); setCopied(true); setTimeout(() => setCopied(false), 2000); } catch { /* blocked */ } }}>
            {copied ? "Copied!" : "Copy"}
          </button>
        </div>
      )}
      <PrimaryButton type="button" variant="outline" className="w-full justify-center" onClick={regenerate} disabled={regenerating}>
        <RefreshCw className={`h-4 w-4 ${regenerating ? "animate-spin" : ""}`} />
        {url ? "Make a new link (old one stops working)" : "Make a login link"}
      </PrimaryButton>
    </Modal>
  );
}

function EditStaffModal({ businessId, member, onClose, onSaved }) {
  const [role, setRole] = useState(member.role);
  const [permissions, setPermissions] = useState(fullMatrix(member.permissions));
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");

  const pickRole = (r) => {
    setRole(r);
    setPermissions(defaultPermissions(r));
  };

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setErr("");
    try {
      await authApi.updateStaff(businessId, member.id, { role, permissions });
      onSaved();
    } catch (er) {
      setErr(er.response?.data?.detail || er.response?.data?.error || "Couldn't save the changes.");
    } finally { setSaving(false); }
  };

  return (
    <Modal title={`Manage ${member.user_name || "staff member"}`} subtitle={member.user_email || "Signs in with an old login link"} onClose={onClose} wide>
      {err && <p role="alert" className="mb-3 rounded-xl bg-red-500/10 px-3 py-2.5 text-sm text-red-300">{err}</p>}
      <form onSubmit={submit} className="space-y-4">
        <div>
          <p className="mb-2 text-sm font-semibold text-white">Role</p>
          <RolePicker value={role} onChange={pickRole} />
        </div>
        <div>
          <p className="mb-2 text-sm font-semibold text-white">Permissions</p>
          <PermissionMatrix permissions={permissions} onChange={setPermissions} readonly={false} />
          <p className="mt-2 text-xs text-navy-400">Changes apply as soon as you save.</p>
        </div>
        <div className="flex flex-col-reverse gap-2 sm:flex-row">
          <PrimaryButton type="button" variant="outline" className="justify-center" onClick={onClose}>Cancel</PrimaryButton>
          <PrimaryButton type="submit" className="flex-1 justify-center" disabled={saving}>{saving ? "Saving…" : "Save changes"}</PrimaryButton>
        </div>
      </form>
    </Modal>
  );
}

function ViewPermissionsModal({ member, onClose }) {
  return (
    <Modal title={member.user_name || "Staff member"} subtitle={roleLabel(member.role)} onClose={onClose} wide>
      <PermissionMatrix permissions={member.permissions} onChange={() => {}} readonly />
      <PrimaryButton type="button" variant="outline" onClick={onClose} className="mt-4 w-full justify-center">Close</PrimaryButton>
    </Modal>
  );
}

/* ─── Staff Activity — the owner-facing "who changed what, and when" log
     (accounts.StaffActivity via /api/staff/audit-log/). Filterable by staff
     member, module, action and date; each row is the server's own
     already-formatted description ("Updated Invoice INV-4 — Amount paid:
     0.00 → 500.00"), so nothing here re-derives the before/after text. ─── */
const AUDIT_MODULES = [
  ["sales", "Sales"], ["purchases", "Purchases"], ["expenses", "Expenses"], ["inventory", "Inventory"],
  ["parties", "Parties"], ["payments", "Payments"], ["banking", "Banking"], ["reports", "Reports"], ["staff", "Staff"],
];
const AUDIT_ACTION_META = {
  CREATE: { label: "Created", icon: FilePlus, color: "text-green-400 bg-green-500/10" },
  UPDATE: { label: "Updated", icon: FilePen, color: "text-blue-400 bg-blue-500/10" },
  DELETE: { label: "Deleted", icon: FileX, color: "text-red-400 bg-red-500/10" },
};
const AUDIT_PAGE_SIZE = 50;

function StaffActivityLog({ businessId, staff }) {
  const [rows, setRows] = useState([]);
  const [count, setCount] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [staffFilter, setStaffFilter] = useState("");
  const [moduleFilter, setModuleFilter] = useState("");
  const [actionFilter, setActionFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");

  const load = () => {
    if (!businessId) return;
    setLoading(true);
    setError("");
    const params = { page, page_size: AUDIT_PAGE_SIZE };
    if (staffFilter) params.staff = staffFilter;
    if (moduleFilter) params.module = moduleFilter;
    if (actionFilter) params.action = actionFilter;
    if (dateFrom) params.date_from = dateFrom;
    if (dateTo) params.date_to = dateTo;
    authApi.staffAuditLog(params)
      .then((r) => {
        const data = r.data;
        setRows(data?.results ?? data ?? []);
        setCount(data?.count ?? (Array.isArray(data) ? data.length : 0));
      })
      .catch((e) => {
        // 403 here means this signed-in staff member wasn't given the "staff"
        // module — same access rule the backend enforces, not a real error.
        setRows([]);
        setCount(0);
        setError(
          e.response?.status === 403
            ? "You don't have access to staff activity. Ask the business owner to enable it for you."
            : "Couldn't load staff activity."
        );
      })
      .finally(() => setLoading(false));
  };

  useEffect(load, [businessId, page, staffFilter, moduleFilter, actionFilter, dateFrom, dateTo]);
  useEffect(() => setPage(1), [staffFilter, moduleFilter, actionFilter, dateFrom, dateTo]);

  const totalPages = Math.max(1, Math.ceil(count / AUDIT_PAGE_SIZE));

  return (
    <SectionCard
      title="Staff Activity"
      subtitle="Every sale, purchase, expense and more that staff created, edited or deleted — with before/after values on edits."
    >
      <div className="mb-4 flex flex-wrap gap-2">
        <select value={staffFilter} onChange={(e) => setStaffFilter(e.target.value)}
          className="rounded-lg border border-navy-700 bg-navy-800 px-2.5 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none">
          <option value="">All staff</option>
          {staff.map((m) => (
            <option key={m.user} value={m.user}>{m.user_name || m.user_email || `#${m.user}`}</option>
          ))}
        </select>
        <select value={moduleFilter} onChange={(e) => setModuleFilter(e.target.value)}
          className="rounded-lg border border-navy-700 bg-navy-800 px-2.5 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none">
          <option value="">All features</option>
          {AUDIT_MODULES.map(([key, label]) => <option key={key} value={key}>{label}</option>)}
        </select>
        <select value={actionFilter} onChange={(e) => setActionFilter(e.target.value)}
          className="rounded-lg border border-navy-700 bg-navy-800 px-2.5 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none">
          <option value="">All actions</option>
          {Object.entries(AUDIT_ACTION_META).map(([key, meta]) => <option key={key} value={key}>{meta.label}</option>)}
        </select>
        <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)}
          className="rounded-lg border border-navy-700 bg-navy-800 px-2.5 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none" />
        <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)}
          className="rounded-lg border border-navy-700 bg-navy-800 px-2.5 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none" />
        {(staffFilter || moduleFilter || actionFilter || dateFrom || dateTo) && (
          <button
            onClick={() => { setStaffFilter(""); setModuleFilter(""); setActionFilter(""); setDateFrom(""); setDateTo(""); }}
            className="rounded-lg px-2.5 py-1.5 text-xs text-navy-400 hover:text-white"
          >
            Clear filters
          </button>
        )}
      </div>

      {error ? (
        <p className="flex items-center gap-2 py-8 text-center text-sm text-navy-400 justify-center">
          <AlertCircle className="h-4 w-4 shrink-0 text-orange-400" /> {error}
        </p>
      ) : loading ? (
        <p className="py-8 text-center text-sm text-navy-500">Loading…</p>
      ) : rows.length === 0 ? (
        <div className="flex flex-col items-center gap-2 py-10 text-center">
          <History className="h-10 w-10 text-navy-700" />
          <p className="text-sm text-navy-400">No activity found.</p>
        </div>
      ) : (
        <>
          <div className="space-y-1.5">
            {rows.map((a) => {
              const meta = AUDIT_ACTION_META[a.action] || AUDIT_ACTION_META.UPDATE;
              const Icon = meta.icon;
              return (
                <div key={a.id} className="flex items-start gap-3 rounded-xl border border-navy-800 bg-navy-950 px-3 py-2.5">
                  <div className={`mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg ${meta.color}`}>
                    <Icon className="h-3.5 w-3.5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm text-white">{a.description}</p>
                    <p className="mt-0.5 text-xs text-navy-500">
                      {a.user_name || a.user_email || "Unknown"} · {new Date(a.timestamp).toLocaleString()}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>

          {totalPages > 1 && (
            <div className="mt-4 flex items-center justify-between text-xs text-navy-400">
              <span>Page {page} of {totalPages} · {count} total</span>
              <div className="flex gap-1.5">
                <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}
                  className="flex items-center gap-1 rounded-lg border border-navy-700 px-2 py-1 disabled:opacity-40">
                  <ChevronLeft className="h-3.5 w-3.5" /> Prev
                </button>
                <button disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}
                  className="flex items-center gap-1 rounded-lg border border-navy-700 px-2 py-1 disabled:opacity-40">
                  Next <ChevronRight className="h-3.5 w-3.5" />
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </SectionCard>
  );
}

export default function StaffPage() {
  const { currentBusiness, user } = useAuth();
  const { t } = useTranslation();
  const [staff, setStaff] = useState([]);
  const [invites, setInvites] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showInvite, setShowInvite] = useState(false);
  const [viewingPerms, setViewingPerms] = useState(null);
  const [viewingLink, setViewingLink] = useState(null);
  const [editingMember, setEditingMember] = useState(null);
  const [removingMember, setRemovingMember] = useState(null);
  const [cancellingInvite, setCancellingInvite] = useState(null);
  const [resent, setResent] = useState(null);
  const [busyInvite, setBusyInvite] = useState(null);
  const [notice, setNotice] = useState("");
  const [search, setSearch] = useState("");

  const businessId = currentBusiness?.id;

  const load = () => {
    if (!businessId) return;
    setLoading(true);
    Promise.all([
      authApi.staff(businessId).then((r) => setStaff(r.data.results ?? r.data)),
      authApi.staffInvitations(businessId).then((r) => setInvites(r.data.results ?? r.data)),
    ])
      // A 403 here (e.g. Staff Management switched off/Premium-only for this
      // business — see require_feature("staff_management") on the backend)
      // is expected and handled by the route's <FeatureGate>.
      .catch(() => {})
      .finally(() => setLoading(false));
  };

  useEffect(load, [businessId]);

  const resend = async (inv) => {
    setBusyInvite(inv.id);
    setNotice("");
    try {
      const { data } = await authApi.resendStaffInvite(businessId, inv.id);
      setResent(data);
      load();
    } catch (er) {
      setNotice(er.response?.data?.error || "Couldn't resend the invitation.");
    } finally { setBusyInvite(null); }
  };

  // Mirrors the backend (accounts/views.py PLATFORM_LIMITS): 5 staff per
  // business from the website, on any plan; active staff plus invitations
  // still waiting count. A Super Admin override wins.
  const openInvites = invites.filter((i) => !i.is_expired);
  const used = staff.filter((m) => m.role !== "OWNER" && m.is_active !== false).length + openInvites.length;
  const staffLimit = currentBusiness?.staff_limit_override ?? 5;
  const atStaffLimit = used >= staffLimit;

  const owner = staff.find((m) => m.role === "OWNER");
  const team = staff.filter((m) => m.role !== "OWNER").filter((m) => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return [m.user_name, m.user_email, roleLabel(m.role)].some((v) => (v || "").toLowerCase().includes(q));
  });

  const iconBtn = "flex h-10 w-10 items-center justify-center rounded-xl border border-navy-700 text-navy-200 transition hover:border-orange-500/60 hover:text-orange-300";
  const textBtn = "rounded-xl border border-navy-700 px-3 py-2 text-sm font-medium text-navy-100 transition hover:border-orange-500/60 hover:text-orange-300 disabled:opacity-60";

  return (
    <div>
      <PageHeader
        title={t("staffManagement")}
        subtitle="Add staff, choose what each person can do, and send them an invitation."
        action={
          <PrimaryButton onClick={() => setShowInvite(true)} disabled={atStaffLimit}>
            <Plus className="h-4 w-4" /> Add New Staff
          </PrimaryButton>
        }
      />

      {atStaffLimit && (
        <div className="mb-5 rounded-2xl border border-orange-500/20 bg-orange-500/5 px-4 py-3 text-sm text-orange-200">
          A business can have up to {staffLimit} staff member{staffLimit !== 1 ? "s" : ""} besides the admin
          (waiting invitations count too). Remove someone or cancel an invitation to add another.
        </div>
      )}
      {notice && <p role="alert" className="mb-4 rounded-xl bg-red-500/10 px-3 py-2.5 text-sm text-red-300">{notice}</p>}

      {/* Admin */}
      <SectionCard title="Admin">
        <div className="flex items-center gap-3 rounded-xl border border-orange-500/20 bg-orange-500/5 px-4 py-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-orange-500/15 text-orange-300">
            <Crown className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <p className="truncate font-semibold text-white">{owner?.user_name || currentBusiness?.owner_name || user?.name || "Business Admin"}</p>
            <p className="text-sm text-navy-300">Business Admin · <span className="text-green-300">Full business access</span></p>
          </div>
        </div>
      </SectionCard>

      {/* Waiting invitations */}
      {invites.length > 0 && (
        <div className="mt-6">
          <SectionCard title={`Invitations waiting (${invites.length})`}>
            <div className="space-y-2">
              {invites.map((inv) => (
                <div key={inv.id} className="flex flex-col gap-3 rounded-xl border border-navy-800 bg-navy-950 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
                  <div className="min-w-0">
                    <p className="truncate font-semibold text-white">{inv.name}</p>
                    <p className="text-sm text-navy-300">{inv.role_label}{inv.email ? ` · ${inv.email}` : ""}</p>
                    <p className={`mt-0.5 flex items-center gap-1.5 text-xs ${inv.is_expired ? "text-red-300" : "text-amber-300"}`}>
                      <Clock className="h-3.5 w-3.5" />
                      {inv.is_expired ? "Expired — resend to send a new link" : `Invitation pending · expires ${new Date(inv.expires_at).toLocaleDateString()}`}
                    </p>
                  </div>
                  <div className="flex gap-2">
                    <button type="button" className={textBtn} disabled={busyInvite === inv.id} onClick={() => resend(inv)}>
                      <span className="flex items-center gap-1.5"><RefreshCw className={`h-4 w-4 ${busyInvite === inv.id ? "animate-spin" : ""}`} /> Resend</span>
                    </button>
                    <button type="button" className={`${textBtn} hover:border-red-500/60 hover:text-red-300`} onClick={() => setCancellingInvite(inv)}>
                      Cancel
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </SectionCard>
        </div>
      )}

      {/* Staff */}
      <div className="mt-6">
        <SectionCard title={`Staff (${staff.filter((m) => m.role !== "OWNER").length})`}>
          {staff.length > 2 && (
            <div className="relative mb-4">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-400" />
              <input
                value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search name, email, role…"
                className="w-full rounded-xl border border-navy-700 bg-navy-950 py-3 pl-9 pr-3 text-base text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
              />
            </div>
          )}
          {loading ? (
            <p className="py-6 text-center text-sm text-navy-300">{t("loading")}</p>
          ) : team.length ? (
            <div className="space-y-2">
              {team.map((member) => (
                <div key={member.id} className="flex flex-col gap-3 rounded-xl border border-navy-800 bg-navy-950 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex min-w-0 items-center gap-3">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-navy-800 font-bold text-white">
                      {(member.user_name || member.user_email || "?")[0].toUpperCase()}
                    </div>
                    <div className="min-w-0">
                      <p className="truncate font-semibold text-white">{member.user_name || member.user_email}</p>
                      <p className="truncate text-sm text-navy-300">
                        {roleLabel(member.role)}{member.user_email ? ` · ${member.user_email}` : " · old login link"}
                      </p>
                      <p className={`mt-0.5 text-xs font-medium ${member.is_active ? "text-green-300" : "text-red-300"}`}>
                        {member.is_active ? "✓ Active" : "Inactive — can't use the business"}
                      </p>
                    </div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <button onClick={() => setEditingMember(member)} className={`${textBtn} flex items-center gap-1.5`}>
                      <Edit2 className="h-4 w-4" /> Manage
                    </button>
                    <button onClick={() => setViewingPerms(member)} className={iconBtn} title="See permissions" aria-label="See permissions">
                      <UserCheck className="h-4 w-4" />
                    </button>
                    {!member.user_email && (
                      <button onClick={() => setViewingLink(member)} className={iconBtn} title="Old login link" aria-label="Old login link">
                        <Link2 className="h-4 w-4" />
                      </button>
                    )}
                    <button
                      onClick={async () => {
                        try {
                          await authApi.updateStaff(businessId, member.id, { is_active: !member.is_active });
                          load();
                        } catch (er) {
                          setNotice(er.response?.data?.detail || er.response?.data?.error || "Couldn't change this.");
                        }
                      }}
                      className={textBtn}
                    >
                      {member.is_active ? "Deactivate" : "Activate"}
                    </button>
                    <button onClick={() => setRemovingMember(member)} className={`${iconBtn} hover:border-red-500/60 hover:text-red-300`} title="Remove" aria-label="Remove staff member">
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : staff.some((m) => m.role !== "OWNER") ? (
            <p className="py-6 text-center text-sm text-navy-300">No matching staff</p>
          ) : (
            <div className="flex flex-col items-center gap-3 py-8 text-center">
              <UserCheck className="h-12 w-12 text-navy-600" />
              <p className="text-sm text-navy-300">No staff yet. Add someone and send them an invitation.</p>
              {!atStaffLimit && <PrimaryButton onClick={() => setShowInvite(true)}><Plus className="h-4 w-4" /> Add New Staff</PrimaryButton>}
            </div>
          )}
        </SectionCard>
      </div>

      <div className="mt-6">
        <StaffActivityLog businessId={businessId} staff={staff} />
      </div>

      {showInvite && (
        <InviteModal
          businessId={businessId}
          businessName={currentBusiness?.name}
          onClose={() => setShowInvite(false)}
          onSaved={() => { setShowInvite(false); load(); }}
        />
      )}
      {resent && (
        <Modal title="New invitation link" subtitle={`${resent.name} · ${resent.role_label} — the old link no longer works`} onClose={() => setResent(null)}>
          <InviteSharePanel name={resent.name} businessName={currentBusiness?.name} token={resent.token} />
          <PrimaryButton type="button" className="mt-4 w-full justify-center" onClick={() => setResent(null)}>Done</PrimaryButton>
        </Modal>
      )}
      {viewingPerms && <ViewPermissionsModal member={viewingPerms} onClose={() => setViewingPerms(null)} />}
      {viewingLink && (
        <LegacyLinkModal
          businessId={businessId}
          member={viewingLink}
          onClose={() => setViewingLink(null)}
          onUpdated={(updated) => setStaff((prev) => prev.map((m) => (m.id === updated.id ? updated : m)))}
        />
      )}
      {editingMember && (
        <EditStaffModal
          businessId={businessId}
          member={editingMember}
          onClose={() => setEditingMember(null)}
          onSaved={() => { setEditingMember(null); load(); }}
        />
      )}
      {removingMember && (
        <ConfirmDialog
          message={`Remove ${removingMember.user_name || removingMember.user_email} from this business? They lose access immediately.`}
          onConfirm={async () => {
            try { await authApi.removeStaff(businessId, removingMember.id); } catch { setNotice("Couldn't remove this staff member."); }
            setRemovingMember(null);
            load();
          }}
          onCancel={() => setRemovingMember(null)}
        />
      )}
      {cancellingInvite && (
        <ConfirmDialog
          message={`Cancel the invitation for ${cancellingInvite.name}? The link will stop working.`}
          onConfirm={async () => {
            try { await authApi.cancelStaffInvite(businessId, cancellingInvite.id); } catch { setNotice("Couldn't cancel the invitation."); }
            setCancellingInvite(null);
            load();
          }}
          onCancel={() => setCancellingInvite(null)}
        />
      )}
    </div>
  );
}
