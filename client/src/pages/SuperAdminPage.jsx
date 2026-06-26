import { useState, useEffect, useMemo } from "react";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import { superadmin as adminApi } from "../api";
import { useAuth } from "../context/AuthContext";
import { useTranslation } from "../utils/translations";
import { useNavigate } from "react-router-dom";
import {
  adToBS, BS_MONTH_NAMES_EN, BS_MONTH_NAMES_NE, bsMonthStartWeekday,
  getBSMonthADDates, formatBS, toNepaliDigits,
} from "../utils/nepaliDate";
import {
  Users, Building2, ShieldCheck, CheckCircle2, XCircle, X,
  CalendarDays, ChevronLeft, ChevronRight, Activity,
} from "lucide-react";

/* ── Calendar component (AD + BS) ── */
function LoginCalendar({ loginDates, lang }) {
  const today = new Date();
  const [calMode, setCalMode] = useState("AD"); // "AD" | "BS"
  const [adYear, setAdYear] = useState(today.getFullYear());
  const [adMonth, setAdMonth] = useState(today.getMonth()); // 0-indexed

  // BS current view
  const todayBS = adToBS(today);
  const [bsYear, setBsYear] = useState(todayBS.year);
  const [bsMonth, setBsMonth] = useState(todayBS.month); // 1-indexed

  // Set of date strings "YYYY-MM-DD" that have logins
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

  /* ── AD calendar render ── */
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
          {["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].map((d) => (
            <div key={d} className="py-1 text-[10px] font-semibold text-navy-400">{d}</div>
          ))}
          {cells.map((day, i) => {
            if (!day) return <div key={`empty-${i}`} />;
            const key = adKey(adYear, adMonth, day);
            const hasLogin = loginSet.has(key);
            const isToday = adYear === today.getFullYear() && adMonth === today.getMonth() && day === today.getDate();
            return (
              <div
                key={day}
                className={`relative flex h-8 w-full items-center justify-center rounded-lg text-xs transition ${
                  isToday ? "border border-orange-500/50 bg-orange-500/10 font-bold text-orange-400"
                  : hasLogin ? "bg-green-500/15 text-green-400 font-medium"
                  : "text-navy-300"
                }`}
              >
                {day}
                {hasLogin && (
                  <span className="absolute bottom-0.5 left-1/2 -translate-x-1/2 h-1 w-1 rounded-full bg-green-400" />
                )}
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  /* ── BS calendar render ── */
  function renderBS() {
    const monthDates = getBSMonthADDates(bsYear, bsMonth);
    const startWd = bsMonthStartWeekday(bsYear, bsMonth);
    const monthNameEN = BS_MONTH_NAMES_EN[bsMonth - 1];
    const monthNameNE = BS_MONTH_NAMES_NE[bsMonth - 1];
    const monthLabel = lang === "ne" ? `${monthNameNE} ${toNepaliDigits(bsYear)}` : `${monthNameEN} ${bsYear} BS`;

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
          {["आ","सो","मं","बु","वि","शु","श"].map((d) => (
            <div key={d} className="py-1 text-[10px] font-semibold text-navy-400">{d}</div>
          ))}
          {cells.map((cell, i) => {
            if (!cell) return <div key={`empty-${i}`} />;
            const { bsDay, adDate } = cell;
            const adKey2 = `${adDate.getFullYear()}-${String(adDate.getMonth() + 1).padStart(2, "0")}-${String(adDate.getDate()).padStart(2, "0")}`;
            const hasLogin = loginSet.has(adKey2);
            const isToday = `${bsYear}-${bsMonth}-${bsDay}` === todayBSKey;
            const label = lang === "ne" ? toNepaliDigits(bsDay) : bsDay;
            return (
              <div
                key={bsDay}
                className={`relative flex h-8 w-full items-center justify-center rounded-lg text-xs transition ${
                  isToday ? "border border-orange-500/50 bg-orange-500/10 font-bold text-orange-400"
                  : hasLogin ? "bg-green-500/15 text-green-400 font-medium"
                  : "text-navy-300"
                }`}
              >
                {label}
                {hasLogin && (
                  <span className="absolute bottom-0.5 left-1/2 -translate-x-1/2 h-1 w-1 rounded-full bg-green-400" />
                )}
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* Mode toggle */}
      <div className="mb-4 flex gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1 w-fit">
        {["AD", "BS"].map((m) => (
          <button
            key={m}
            onClick={() => setCalMode(m)}
            className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
              calMode === m ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"
            }`}
          >
            {m}
          </button>
        ))}
      </div>
      {calMode === "AD" ? renderAD() : renderBS()}
    </div>
  );
}

/* ── User Detail Modal ── */
function UserDetailModal({ user: u, onClose }) {
  const { t, language } = useTranslation();
  const [activity, setActivity] = useState([]);
  const [loadingActivity, setLoadingActivity] = useState(true);

  useEffect(() => {
    adminApi.userLoginActivity(u.id)
      .then((r) => setActivity(r.data))
      .catch(() => setActivity([]))
      .finally(() => setLoadingActivity(false));
  }, [u.id]);

  const loginDates = activity.map((a) => a.timestamp);
  const todayBS = adToBS(new Date());
  const joinedBS = adToBS(new Date(u.created_at));

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
              {u.is_platform_admin && (
                <span className="mt-0.5 inline-block rounded-lg bg-orange-500/15 px-2 py-0.5 text-[10px] font-semibold text-orange-400">
                  Platform Admin
                </span>
              )}
            </div>
          </div>
          <button onClick={onClose}><X className="h-5 w-5 text-navy-400" /></button>
        </div>

        {/* Stats row */}
        <div className="mb-5 grid grid-cols-3 gap-3">
          <div className="rounded-xl border border-navy-800 bg-navy-950 px-3 py-2.5 text-center">
            <p className="text-[10px] text-navy-400">{t("totalLogins")}</p>
            <p className="mt-1 text-lg font-bold text-white">{activity.length}</p>
          </div>
          <div className="rounded-xl border border-navy-800 bg-navy-950 px-3 py-2.5 text-center">
            <p className="text-[10px] text-navy-400">{t("accountType")}</p>
            <p className="mt-1 text-sm font-semibold text-orange-400 capitalize">{u.account_type}</p>
          </div>
          <div className="rounded-xl border border-navy-800 bg-navy-950 px-3 py-2.5 text-center">
            <p className="text-[10px] text-navy-400">{t("verified")}</p>
            <p className={`mt-1 text-sm font-semibold ${u.is_verified ? "text-green-400" : "text-red-400"}`}>
              {u.is_verified ? "Yes" : "No"}
            </p>
          </div>
        </div>

        {/* Joined dates (AD + BS) */}
        <div className="mb-5 rounded-xl border border-navy-800 bg-navy-950 px-4 py-3">
          <p className="text-xs text-navy-400 mb-1">{t("joinedOn")}</p>
          <p className="text-sm font-medium text-white">
            AD: {new Date(u.created_at).toLocaleDateString()}
          </p>
          <p className="text-sm font-medium text-orange-300">
            BS: {formatBS(joinedBS, language)}
          </p>
        </div>

        {/* Calendar */}
        <div className="rounded-xl border border-navy-800 bg-navy-950 p-4">
          <div className="mb-3 flex items-center gap-2">
            <CalendarDays className="h-4 w-4 text-orange-400" />
            <p className="text-sm font-semibold text-white">{t("loginActivity")}</p>
          </div>
          {loadingActivity ? (
            <p className="py-4 text-center text-xs text-navy-400">{t("loading")}</p>
          ) : (
            <LoginCalendar loginDates={loginDates} lang={language} />
          )}
          <div className="mt-3 flex items-center gap-3 text-[10px] text-navy-400">
            <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-green-400 inline-block" /> Login day</span>
            <span className="flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-orange-400 inline-block" /> Today</span>
          </div>
        </div>

        {/* Recent logins */}
        {activity.length > 0 && (
          <div className="mt-4">
            <p className="mb-2 text-xs font-medium text-navy-400">Recent Logins</p>
            <div className="space-y-1 max-h-36 overflow-y-auto">
              {activity.slice(0, 10).map((a) => {
                const d = new Date(a.timestamp);
                const bs = adToBS(d);
                return (
                  <div key={a.id} className="flex items-center justify-between rounded-lg border border-navy-800 bg-navy-950 px-3 py-1.5 text-xs">
                    <span className="text-navy-300">{d.toLocaleString()}</span>
                    <span className="text-orange-300">{formatBS(bs, language)}</span>
                    <span className={`rounded px-1.5 py-0.5 ${a.success ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"}`}>
                      {a.success ? "✓" : "✗"}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        <div className="mt-4">
          <PrimaryButton variant="outline" onClick={onClose} className="w-full">{t("close")}</PrimaryButton>
        </div>
      </div>
    </div>
  );
}

/* ── Main SuperAdminPage ── */
export default function SuperAdminPage() {
  const { user } = useAuth();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [stats, setStats] = useState(null);
  const [businesses, setBusinesses] = useState([]);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState("overview");
  const [selectedUser, setSelectedUser] = useState(null);

  useEffect(() => {
    if (!user?.is_platform_admin) { navigate("/dashboard"); return; }
    Promise.all([adminApi.stats(), adminApi.businesses(), adminApi.users()])
      .then(([s, b, u]) => {
        setStats(s.data);
        setBusinesses(b.data);
        setUsers(u.data);
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
        title={t("superAdmin")}
        subtitle="Monitor and manage all businesses on the platform."
      />

      {/* Tabs */}
      <div className="mb-6 flex gap-1 rounded-xl border border-navy-800 bg-navy-900 p-1 w-fit flex-wrap">
        {tabs.map((tab_item) => (
          <button
            key={tab_item}
            onClick={() => setTab(tab_item)}
            className={`rounded-lg px-4 py-2 text-sm font-medium capitalize transition ${
              tab === tab_item ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"
            }`}
          >
            {tab_item}
          </button>
        ))}
      </div>

      {loading ? (
        <p className="text-sm text-navy-400">{t("loading")}</p>
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
            <SectionCard title={`Platform Users (${users.length})`}>
              {users.length === 0 ? (
                <p className="py-6 text-center text-sm text-navy-400">{t("noActivity")}</p>
              ) : (
                <div className="space-y-2">
                  {users.map((u) => (
                    <div key={u.id} className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-navy-800 text-sm font-bold text-white">
                          {u.name?.[0]?.toUpperCase() || "U"}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <p className="text-sm font-medium text-white">{u.name || "—"}</p>
                            {u.is_platform_admin && (
                              <span className="rounded bg-orange-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-orange-400">Admin</span>
                            )}
                          </div>
                          <p className="text-xs text-navy-400">{u.email} · {u.account_type}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className={`rounded-lg px-2 py-1 text-xs ${u.is_verified ? "bg-green-500/10 text-green-400" : "bg-yellow-500/10 text-yellow-400"}`}>
                          {u.is_verified ? "Verified" : "Unverified"}
                        </span>
                        <button
                          onClick={() => setSelectedUser(u)}
                          className="flex items-center gap-1.5 rounded-lg border border-navy-700 px-2.5 py-1 text-xs text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400"
                        >
                          <CalendarDays className="h-3 w-3" /> {t("userDetail")}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </SectionCard>
          )}

          {tab === "activity" && (
            <SectionCard title="Login Activity">
              <p className="text-sm text-navy-400">Activity logs coming soon.</p>
            </SectionCard>
          )}
        </>
      )}

      {selectedUser && (
        <UserDetailModal user={selectedUser} onClose={() => setSelectedUser(null)} />
      )}
    </div>
  );
}
