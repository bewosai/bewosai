import { useState, useEffect } from "react";
import { useAuth } from "../context/AuthContext";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { auth as authApi } from "../api";
import { UserCheck, Plus, Shield, Eye, X, Crown } from "lucide-react";

const ROLE_META = {
  OWNER:   { label: "Owner",   icon: Crown,      color: "text-orange-400 bg-orange-500/10" },
  MANAGER: { label: "Manager", icon: Shield,      color: "text-blue-400 bg-blue-500/10" },
  CASHIER: { label: "Cashier", icon: UserCheck,   color: "text-green-400 bg-green-500/10" },
  VIEWER:  { label: "Viewer",  icon: Eye,         color: "text-navy-400 bg-navy-800" },
};

function InviteModal({ businessId, onClose, onSaved }) {
  const [form, setForm] = useState({ email: "", name: "", role: "CASHIER", password: "" });
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState("");
  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500";

  const submit = async (e) => {
    e.preventDefault();
    if (!form.email || !form.name || !form.password) { setErr("All fields required."); return; }
    setSaving(true);
    try {
      await authApi.inviteStaff(businessId, form);
      onSaved();
    } catch (er) {
      setErr(er.response?.data?.email?.[0] || "Failed to invite staff.");
    } finally { setSaving(false); }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-navy-700 bg-navy-900 p-6">
        <div className="mb-5 flex items-center justify-between">
          <h2 className="font-bold text-white">Invite Staff Member</h2>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>
        {err && <p className="mb-4 rounded-xl bg-red-500/10 px-3 py-2 text-xs text-red-400">{err}</p>}
        <form onSubmit={submit} className="space-y-3">
          <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Full name *" className={field} />
          <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="Email *" className={field} />
          <select value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })} className={field}>
            <option value="MANAGER">Manager – Full access except settings</option>
            <option value="CASHIER">Cashier – Sales and expenses</option>
            <option value="VIEWER">Viewer – Read-only</option>
          </select>
          <input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder="Temporary password *" className={field} />
          <p className="text-xs text-navy-500">Staff will log in with this email and password.</p>
          <div className="flex gap-3 pt-1">
            <PrimaryButton type="submit" className="flex-1" disabled={saving}>{saving ? "Inviting…" : "Invite Staff"}</PrimaryButton>
            <PrimaryButton type="button" variant="outline" onClick={onClose}>Cancel</PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function StaffPage() {
  const { currentBusiness } = useAuth();
  const [staff, setStaff] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showInvite, setShowInvite] = useState(false);

  const load = () => {
    if (!currentBusiness?.id) return;
    setLoading(true);
    authApi.staff(currentBusiness.id)
      .then((r) => setStaff(r.data.results ?? r.data))
      .finally(() => setLoading(false));
  };

  useEffect(load, [currentBusiness?.id]);

  return (
    <div>
      <PageHeader
        title="Staff Management"
        subtitle="Invite team members and manage their access roles."
        action={
          <PrimaryButton onClick={() => setShowInvite(true)}>
            <Plus className="h-4 w-4" /> Invite Staff
          </PrimaryButton>
        }
      />

      {/* Roles info */}
      <div className="mb-6 grid gap-3 sm:grid-cols-4">
        {Object.entries(ROLE_META).map(([key, meta]) => {
          const Icon = meta.icon;
          return (
            <div key={key} className="rounded-xl border border-navy-800 bg-navy-900 px-4 py-3 flex items-center gap-3">
              <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${meta.color}`}>
                <Icon className="h-4 w-4" />
              </div>
              <div>
                <p className="text-sm font-medium text-white">{meta.label}</p>
                <p className="text-xs text-navy-400">
                  {key === "OWNER" ? "Full control" : key === "MANAGER" ? "Most features" : key === "CASHIER" ? "Sales & exp." : "View only"}
                </p>
              </div>
            </div>
          );
        })}
      </div>

      <SectionCard title={`Team Members (${staff.length})`}>
        {loading ? (
          <p className="py-6 text-center text-sm text-navy-400">Loading staff…</p>
        ) : staff.length ? (
          <div className="space-y-2">
            {staff.map((member) => {
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
                  <div className="flex items-center gap-2">
                    <span className={`flex items-center gap-1.5 rounded-lg px-2.5 py-1 text-xs font-medium ${meta.color}`}>
                      <Icon className="h-3 w-3" /> {meta.label}
                    </span>
                    <span className={`rounded-lg px-2 py-1 text-xs ${member.is_active ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"}`}>
                      {member.is_active ? "Active" : "Inactive"}
                    </span>
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
    </div>
  );
}
