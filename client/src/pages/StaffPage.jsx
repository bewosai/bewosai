import { useState, useEffect } from "react";
import { useAuth } from "../context/AuthContext";
import { useTranslation } from "../utils/translations";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { auth as authApi } from "../api";
import { UserCheck, Plus, Shield, Eye, X, Crown, ChevronDown, ChevronUp, Check, Edit2, Trash2, Search } from "lucide-react";
import ConfirmDialog from "../components/common/ConfirmDialog";

const ROLE_META = {
  OWNER:   { label: "Owner",   icon: Crown,      color: "text-orange-400 bg-orange-500/10" },
  MANAGER: { label: "Manager", icon: Shield,      color: "text-blue-400 bg-blue-500/10" },
  CASHIER: { label: "Cashier", icon: UserCheck,   color: "text-green-400 bg-green-500/10" },
  VIEWER:  { label: "Viewer",  icon: Eye,         color: "text-navy-400 bg-navy-800" },
};

const MODULES = ["sales", "purchases", "expenses", "inventory", "parties", "payments", "banking", "staff", "reports"];
const ACTIONS = ["view", "create", "edit", "delete"];

const DEFAULT_PERMISSIONS = {
  OWNER: Object.fromEntries(MODULES.map((m) => [m, { view: true, create: true, edit: true, delete: true }])),
  MANAGER: {
    sales:     { view: true,  create: true,  edit: true,  delete: false },
    purchases: { view: true,  create: true,  edit: true,  delete: false },
    expenses:  { view: true,  create: true,  edit: true,  delete: false },
    inventory: { view: true,  create: true,  edit: true,  delete: false },
    parties:   { view: true,  create: true,  edit: true,  delete: false },
    payments:  { view: true,  create: true,  edit: true,  delete: false },
    banking:   { view: true,  create: false, edit: false, delete: false },
    staff:     { view: true,  create: false, edit: false, delete: false },
    reports:   { view: true,  create: false, edit: false, delete: false },
  },
  CASHIER: {
    sales:     { view: true,  create: true,  edit: false, delete: false },
    purchases: { view: false, create: false, edit: false, delete: false },
    expenses:  { view: true,  create: true,  edit: false, delete: false },
    inventory: { view: true,  create: false, edit: false, delete: false },
    parties:   { view: true,  create: true,  edit: false, delete: false },
    payments:  { view: true,  create: true,  edit: false, delete: false },
    banking:   { view: false, create: false, edit: false, delete: false },
    staff:     { view: false, create: false, edit: false, delete: false },
    reports:   { view: true,  create: false, edit: false, delete: false },
  },
  VIEWER: Object.fromEntries(MODULES.map((m) => [m, { view: true, create: false, edit: false, delete: false }])),
};

function PermissionMatrix({ permissions, onChange, readonly }) {
  const { t } = useTranslation();

  const moduleLabel = (m) => t(`mod_${m}`);

  const toggle = (mod, action) => {
    if (readonly) return;
    const current = permissions[mod]?.[action] ?? false;
    onChange({ ...permissions, [mod]: { ...permissions[mod], [action]: !current } });
  };

  const allInRow = (mod) => ACTIONS.every((a) => permissions[mod]?.[a]);
  const toggleRow = (mod) => {
    if (readonly) return;
    const newVal = !allInRow(mod);
    onChange({ ...permissions, [mod]: Object.fromEntries(ACTIONS.map((a) => [a, newVal])) });
  };

  return (
    <div className="overflow-x-auto rounded-xl border border-navy-800">
      <table className="w-full text-xs">
        <thead>
          <tr className="border-b border-navy-800 bg-navy-900">
            <th className="px-3 py-2 text-left text-navy-400">{t("mod_sales").replace("बिक्री", "Module")}</th>
            {ACTIONS.map((a) => (
              <th key={a} className="px-3 py-2 text-center text-navy-400 capitalize">
                {t(a === "delete" ? "deleteLabel" : a)}
              </th>
            ))}
            <th className="px-3 py-2 text-center text-navy-400">{t("all")}</th>
          </tr>
        </thead>
        <tbody>
          {MODULES.map((mod) => (
            <tr key={mod} className="border-b border-navy-800/50 hover:bg-navy-800/30">
              <td className="px-3 py-2 font-medium text-white">{moduleLabel(mod)}</td>
              {ACTIONS.map((action) => {
                const checked = permissions[mod]?.[action] ?? false;
                return (
                  <td key={action} className="px-3 py-2 text-center">
                    <button
                      type="button"
                      onClick={() => toggle(mod, action)}
                      disabled={readonly}
                      className={`mx-auto flex h-5 w-5 items-center justify-center rounded border transition ${
                        checked
                          ? "border-orange-500 bg-orange-500/20 text-orange-400"
                          : "border-navy-700 bg-navy-950 text-navy-700"
                      } ${readonly ? "cursor-default opacity-60" : "hover:border-orange-400"}`}
                    >
                      {checked && <Check className="h-3 w-3" />}
                    </button>
                  </td>
                );
              })}
              <td className="px-3 py-2 text-center">
                <button
                  type="button"
                  onClick={() => toggleRow(mod)}
                  disabled={readonly}
                  className={`mx-auto flex h-5 w-5 items-center justify-center rounded border transition ${
                    allInRow(mod)
                      ? "border-blue-500 bg-blue-500/20 text-blue-400"
                      : "border-navy-700 bg-navy-950 text-navy-700"
                  } ${readonly ? "cursor-default opacity-60" : "hover:border-blue-400"}`}
                >
                  {allInRow(mod) && <Check className="h-3 w-3" />}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function InviteModal({ businessId, onClose, onSaved }) {
  const { t } = useTranslation();
  const [form, setForm] = useState({ email: "", name: "", role: "CASHIER", password: "" });
  const [permissions, setPermissions] = useState(DEFAULT_PERMISSIONS.CASHIER);
  const [showPerms, setShowPerms] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");

  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";

  const handleRoleChange = (role) => {
    setForm((f) => ({ ...f, role }));
    setPermissions(DEFAULT_PERMISSIONS[role] || DEFAULT_PERMISSIONS.CASHIER);
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!form.email || !form.name || !form.password) { setErr("All fields required."); return; }
    setSaving(true);
    try {
      await authApi.inviteStaff(businessId, { ...form, permissions });
      onSaved();
    } catch (er) {
      setErr(er.response?.data?.email?.[0] || "Failed to invite staff.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-2xl rounded-2xl border border-navy-700 bg-navy-900 p-6 max-h-[90vh] overflow-y-auto">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">{t("inviteStaff")}</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>

        {err && <p className="mb-4 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}

        <form onSubmit={submit} className="space-y-3">
          <div className="grid gap-3 sm:grid-cols-2">
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder={`${t("name")} *`}
              className={field}
            />
            <input
              type="email"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              placeholder={`${t("email")} *`}
              className={field}
            />
          </div>

          <input
            type="password"
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
            placeholder="Temporary password *"
            className={field}
          />

          {/* Role selection cards */}
          <div>
            <p className="mb-2 text-xs font-medium text-navy-400">{t("role")}</p>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
              {Object.entries(ROLE_META).filter(([k]) => k !== "OWNER").map(([key, meta]) => {
                const Icon = meta.icon;
                const selected = form.role === key;
                return (
                  <button
                    key={key}
                    type="button"
                    onClick={() => handleRoleChange(key)}
                    className={`flex flex-col items-center gap-1.5 rounded-xl border p-3 text-center transition ${
                      selected
                        ? "border-orange-500 bg-orange-500/10"
                        : "border-navy-700 bg-navy-950 hover:border-navy-600"
                    }`}
                  >
                    <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${meta.color}`}>
                      <Icon className="h-4 w-4" />
                    </div>
                    <p className="text-xs font-semibold text-white">{t(key.toLowerCase())}</p>
                    <p className="text-[10px] text-navy-400">
                      {key === "MANAGER" ? t("mostFeatures") : key === "CASHIER" ? t("salesAndExp") : t("viewOnly")}
                    </p>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Permission matrix toggle */}
          <div>
            <button
              type="button"
              onClick={() => setShowPerms((s) => !s)}
              className="flex w-full items-center justify-between rounded-xl border border-navy-700 bg-navy-950 px-4 py-2.5 text-sm text-white transition hover:border-orange-500/50"
            >
              <span className="font-medium">{t("permissionMatrix")}</span>
              {showPerms ? <ChevronUp className="h-4 w-4 text-navy-400" /> : <ChevronDown className="h-4 w-4 text-navy-400" />}
            </button>
            {showPerms && (
              <div className="mt-2">
                <p className="mb-2 text-xs text-navy-400">
                  Customize exactly what this staff member can access. Defaults are set by their role.
                </p>
                <PermissionMatrix permissions={permissions} onChange={setPermissions} readonly={false} />
              </div>
            )}
          </div>

          <p className="text-xs text-navy-500">Staff will log in with this email and password.</p>

          <div className="flex gap-3 pt-1">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>
              {saving ? "Inviting…" : t("inviteStaff")}
            </PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>{t("cancel")}</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

function EditRoleModal({ businessId, member, onClose, onSaved }) {
  const { t } = useTranslation();
  const [role, setRole] = useState(member.role);
  const [permissions, setPermissions] = useState(
    member.permissions && Object.keys(member.permissions).length
      ? member.permissions
      : DEFAULT_PERMISSIONS[member.role] || DEFAULT_PERMISSIONS.CASHIER
  );
  const [showPerms, setShowPerms] = useState(false);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");

  const handleRoleChange = (r) => {
    setRole(r);
    setPermissions(DEFAULT_PERMISSIONS[r] || DEFAULT_PERMISSIONS.CASHIER);
  };

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await authApi.updateStaff(businessId, member.id, { role, permissions });
      onSaved();
    } catch (er) {
      setErr(er.response?.data?.detail || "Failed to update role.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-2xl rounded-2xl border border-navy-700 bg-navy-900 p-6 max-h-[90vh] overflow-y-auto">
        <div className="mb-5 flex items-center justify-between">
          <div>
            <h2 className="font-bold text-white">Edit Role: {member.user_name}</h2>
            <p className="text-xs text-navy-400 mt-0.5">{member.user_email}</p>
          </div>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {err && <p className="mb-3 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}
        <form onSubmit={submit} className="space-y-4">
          <div>
            <p className="mb-2 text-xs font-medium text-navy-400">{t("role")}</p>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
              {Object.entries(ROLE_META).filter(([k]) => k !== "OWNER").map(([key, meta]) => {
                const Icon = meta.icon;
                const selected = role === key;
                return (
                  <button key={key} type="button" onClick={() => handleRoleChange(key)}
                    className={`flex flex-col items-center gap-1.5 rounded-xl border p-3 text-center transition ${
                      selected ? "border-orange-500 bg-orange-500/10" : "border-navy-700 bg-navy-950 hover:border-navy-600"
                    }`}
                  >
                    <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${meta.color}`}>
                      <Icon className="h-4 w-4" />
                    </div>
                    <p className="text-xs font-semibold text-white">{t(key.toLowerCase())}</p>
                  </button>
                );
              })}
            </div>
          </div>
          <div>
            <button type="button" onClick={() => setShowPerms(s => !s)}
              className="flex w-full items-center justify-between rounded-xl border border-navy-700 bg-navy-950 px-4 py-2.5 text-sm text-white hover:border-orange-500/50">
              <span className="font-medium">{t("permissionMatrix")}</span>
              {showPerms ? <ChevronUp className="h-4 w-4 text-navy-400" /> : <ChevronDown className="h-4 w-4 text-navy-400" />}
            </button>
            {showPerms && (
              <div className="mt-2">
                <PermissionMatrix permissions={permissions} onChange={setPermissions} readonly={false} />
              </div>
            )}
          </div>
          <div className="flex gap-3">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>{saving ? "Saving…" : "Save Changes"}</PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>{t("cancel")}</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

function ViewPermissionsModal({ member, onClose }) {
  const { t } = useTranslation();
  const meta = ROLE_META[member.role] || ROLE_META.VIEWER;
  const Icon = meta.icon;
  const perms = member.permissions && Object.keys(member.permissions).length
    ? member.permissions
    : DEFAULT_PERMISSIONS[member.role] || DEFAULT_PERMISSIONS.VIEWER;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-2xl rounded-2xl border border-navy-700 bg-navy-900 p-6 max-h-[90vh] overflow-y-auto">
        <div className="mb-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-navy-800 text-sm font-bold text-white">
              {member.user_name?.[0]?.toUpperCase() || "?"}
            </div>
            <div>
              <p className="font-bold text-white">{member.user_name}</p>
              <div className={`mt-0.5 inline-flex items-center gap-1.5 rounded-lg px-2 py-0.5 text-xs font-medium ${meta.color}`}>
                <Icon className="h-3 w-3" /> {meta.label}
              </div>
            </div>
          </div>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        <p className="mb-3 text-xs font-medium text-navy-400">{t("permissionMatrix")}</p>
        <PermissionMatrix permissions={perms} onChange={() => {}} readonly={true} />
        <div className="mt-4">
          <PrimaryButton type="button" variant="outline" onClick={onClose} className="w-full">{t("close")}</PrimaryButton>
        </div>
      </div>
    </div>
  );
}

export default function StaffPage() {
  const { currentBusiness } = useAuth();
  const { t } = useTranslation();
  const [staff, setStaff] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showInvite, setShowInvite] = useState(false);
  const [viewingPerms, setViewingPerms] = useState(null);
  const [editingMember, setEditingMember] = useState(null);
  const [removingMember, setRemovingMember] = useState(null);
  const [search, setSearch] = useState("");

  const load = () => {
    if (!currentBusiness?.id) return;
    setLoading(true);
    authApi.staff(currentBusiness.id)
      .then((r) => setStaff(r.data.results ?? r.data))
      // A 403 here (e.g. Staff Management switched off/Premium-only for this
      // business — see require_feature("staff_management") on the backend)
      // is expected and handled by the route's <FeatureGate>; without this
      // catch it surfaces as an unhandled promise rejection instead.
      .catch(() => setStaff([]))
      .finally(() => setLoading(false));
  };

  useEffect(load, [currentBusiness?.id]);

  const filteredStaff = staff.filter((m) => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return (
      (m.user_name || "").toLowerCase().includes(q) ||
      (m.user_email || "").toLowerCase().includes(q) ||
      (m.role || "").toLowerCase().includes(q)
    );
  });

  return (
    <div>
      <PageHeader
        title={t("staffManagement")}
        subtitle="Invite team members and manage their access roles."
        action={
          <PrimaryButton onClick={() => setShowInvite(true)}>
            <Plus className="h-4 w-4" /> {t("inviteStaff")}
          </PrimaryButton>
        }
      />

      {/* Roles overview */}
      <div className="mb-6 grid gap-3 sm:grid-cols-4">
        {Object.entries(ROLE_META).map(([key, meta]) => {
          const Icon = meta.icon;
          return (
            <div key={key} className="rounded-xl border border-navy-800 bg-navy-900 px-4 py-3 flex items-center gap-3">
              <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${meta.color}`}>
                <Icon className="h-4 w-4" />
              </div>
              <div>
                <p className="text-sm font-medium text-white">{t(key.toLowerCase())}</p>
                <p className="text-xs text-navy-400">
                  {key === "OWNER" ? t("fullControl") : key === "MANAGER" ? t("mostFeatures") : key === "CASHIER" ? t("salesAndExp") : t("viewOnly")}
                </p>
              </div>
            </div>
          );
        })}
      </div>

      <SectionCard title={`Team Members (${staff.length})`}>
        {staff.length > 0 && (
          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search name, email, role…"
              className="w-full rounded-xl border border-navy-700 bg-navy-950 py-2.5 pl-9 pr-3 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
            />
          </div>
        )}
        {loading ? (
          <p className="py-6 text-center text-sm text-navy-400">{t("loading")}</p>
        ) : staff.length && filteredStaff.length === 0 ? (
          <p className="py-6 text-center text-sm text-navy-400">No matching staff</p>
        ) : staff.length ? (
          <div className="space-y-2">
            {filteredStaff.map((member) => {
              const meta = ROLE_META[member.role] || ROLE_META.VIEWER;
              const Icon = meta.icon;
              return (
                <div key={member.id} className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3">
                  <div className="flex items-center gap-3">
                    <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-navy-800 text-sm font-bold text-white">
                      {member.user_name?.[0]?.toUpperCase() || "?"}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-white">{member.user_name}</p>
                      <p className="text-xs text-navy-400">{member.user_email}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 flex-wrap justify-end">
                    <span className={`flex items-center gap-1.5 rounded-lg px-2.5 py-1 text-xs font-medium ${meta.color}`}>
                      <Icon className="h-3 w-3" /> {meta.label}
                    </span>
                    <span className={`rounded-lg px-2 py-1 text-xs ${member.is_active ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"}`}>
                      {member.is_active ? t("active") : t("inactive")}
                    </span>
                    <button onClick={() => setViewingPerms(member)}
                      className="rounded-lg border border-navy-700 px-2.5 py-1 text-xs text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400">
                      {t("permissions")}
                    </button>
                    {member.role !== "OWNER" && (
                      <>
                        <button onClick={() => setEditingMember(member)}
                          className="rounded-lg border border-navy-700 p-1.5 text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400"
                          title="Edit role">
                          <Edit2 className="h-3.5 w-3.5" />
                        </button>
                        <button onClick={() => setRemovingMember(member)}
                          className="rounded-lg border border-navy-700 p-1.5 text-navy-300 transition hover:border-red-500/50 hover:text-red-400"
                          title="Remove staff">
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                      </>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="flex flex-col items-center gap-3 py-10 text-center">
            <UserCheck className="h-12 w-12 text-navy-700" />
            <p className="text-sm text-navy-400">No staff members yet.</p>
            <PrimaryButton onClick={() => setShowInvite(true)}><Plus className="h-4 w-4" /> Invite First Staff</PrimaryButton>
          </div>
        )}
      </SectionCard>

      {showInvite && (
        <InviteModal
          businessId={currentBusiness?.id}
          onClose={() => setShowInvite(false)}
          onSaved={() => { setShowInvite(false); load(); }}
        />
      )}

      {viewingPerms && (
        <ViewPermissionsModal member={viewingPerms} onClose={() => setViewingPerms(null)} />
      )}
      {editingMember && (
        <EditRoleModal
          businessId={currentBusiness?.id}
          member={editingMember}
          onClose={() => setEditingMember(null)}
          onSaved={() => { setEditingMember(null); load(); }}
        />
      )}
      {removingMember && (
        <ConfirmDialog
          message={`Remove ${removingMember.user_name} from this business? They will lose access immediately.`}
          onConfirm={async () => {
            try { await authApi.removeStaff(currentBusiness?.id, removingMember.id); } catch {}
            setRemovingMember(null);
            load();
          }}
          onCancel={() => setRemovingMember(null)}
        />
      )}
    </div>
  );
}
