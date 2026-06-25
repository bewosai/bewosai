import { useState, useEffect } from "react";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { superadmin as adminApi } from "../api";
import { useAuth } from "../context/AuthContext";
import { useNavigate } from "react-router-dom";
import {
  Users, Building2, ShieldCheck, TrendingUp,
  Activity, CheckCircle2, XCircle,
} from "lucide-react";

export default function SuperAdminPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [stats, setStats] = useState(null);
  const [businesses, setBusinesses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState("overview");

  useEffect(() => {
    if (!user?.is_platform_admin) { navigate("/dashboard"); return; }
    Promise.all([adminApi.stats(), adminApi.businesses()])
      .then(([s, b]) => {
        setStats(s.data);
        setBusinesses(b.data);
      })
      .finally(() => setLoading(false));
  }, [user]);

  const handleAction = async (id, action) => {
    await adminApi.businessAction(id, action);
    const { data } = await adminApi.businesses();
    setBusinesses(data);
  };

  const tabs = ["overview", "businesses", "users", "activity"];

  return (
    <div>
      <PageHeader
        title="Super Admin Panel"
        subtitle="Monitor and manage all businesses on the platform."
      />

      {/* Tabs */}
      <div className="mb-6 flex gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1 w-fit">
        {tabs.map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`rounded-lg px-4 py-2 text-sm font-medium capitalize transition ${
              tab === t ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {loading ? (
        <p className="text-sm text-navy-400">Loading platform data…</p>
      ) : (
        <>
          {tab === "overview" && stats && (
            <div className="space-y-6">
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {[
                  { label: "Total Businesses", value: stats.total_businesses, icon: Building2 },
                  { label: "Active Businesses", value: stats.active_businesses, icon: CheckCircle2 },
                  { label: "Premium Plans",    value: stats.premium_count,    icon: ShieldCheck },
                  { label: "Total Users",      value: stats.total_users,      icon: Users },
                ].map(({ label, value, icon: Icon }) => (
                  <div key={label} className="rounded-2xl border border-navy-800 bg-navy-900 p-5">
                    <div className="flex items-center justify-between">
                      <p className="text-xs text-navy-400">{label}</p>
                      <Icon className="h-4 w-4 text-orange-400" />
                    </div>
                    <p className="mt-2 text-2xl font-bold text-white">{value}</p>
                  </div>
                ))}
              </div>
              <div className="grid gap-4 sm:grid-cols-3">
                <div className="rounded-2xl border border-navy-800 bg-navy-900 p-5">
                  <p className="text-xs text-navy-400">New This Month</p>
                  <p className="mt-2 text-xl font-bold text-orange-400">{stats.new_this_month}</p>
                </div>
                <div className="rounded-2xl border border-navy-800 bg-navy-900 p-5">
                  <p className="text-xs text-navy-400">Suspended</p>
                  <p className="mt-2 text-xl font-bold text-red-400">{stats.suspended_businesses}</p>
                </div>
                <div className="rounded-2xl border border-navy-800 bg-navy-900 p-5">
                  <p className="text-xs text-navy-400">Logins (30 days)</p>
                  <p className="mt-2 text-xl font-bold text-white">{stats.logins_last_30_days}</p>
                </div>
              </div>
            </div>
          )}

          {tab === "businesses" && (
            <SectionCard title="All Businesses">
              <div className="space-y-2">
                {businesses.map((biz) => (
                  <div key={biz.id} className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-navy-800">
                        <Building2 className="h-4 w-4 text-orange-400" />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-white">{biz.name}</p>
                        <p className="text-xs text-navy-400">{biz.owner_name} · {biz.plan}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className={`rounded-lg px-2.5 py-1 text-xs font-medium ${
                        biz.status === "ACTIVE" ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"
                      }`}>
                        {biz.status}
                      </span>
                      {biz.status === "ACTIVE" ? (
                        <PrimaryButton variant="outline" className="py-1 text-xs" onClick={() => handleAction(biz.id, "suspend")}>
                          Suspend
                        </PrimaryButton>
                      ) : (
                        <PrimaryButton className="py-1 text-xs" onClick={() => handleAction(biz.id, "activate")}>
                          Activate
                        </PrimaryButton>
                      )}
                      {biz.plan === "FREE" && (
                        <PrimaryButton className="py-1 text-xs" onClick={() => handleAction(biz.id, "upgrade")}>
                          Upgrade
                        </PrimaryButton>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </SectionCard>
          )}

          {tab === "users" && (
            <SectionCard title="Platform Users">
              <p className="text-sm text-navy-400">User management coming soon.</p>
            </SectionCard>
          )}

          {tab === "activity" && (
            <SectionCard title="Login Activity">
              <p className="text-sm text-navy-400">Activity logs coming soon.</p>
            </SectionCard>
          )}
        </>
      )}
    </div>
  );
}
