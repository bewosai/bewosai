import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { formatDateOnly } from "../utils/dates";
import { billing as billingApi } from "../api";
import { useAuth } from "../context/AuthContext";
import PageHeader from "../components/shared/PageHeader";
import SectionCard from "../components/shared/SectionCard";
import PrimaryButton from "../components/shared/PrimaryButton";
import {
  ArrowLeft, Crown, Check, Copy, Gift, Loader, Sparkles, Ticket,
  MessageCircle, TrendingUp, AlertCircle,
} from "lucide-react";

const PLAN_META = {
  FREE: { label: "Free", color: "text-navy-300 bg-navy-800", ring: "border-navy-700" },
  PREMIUM: { label: "Premium", color: "text-orange-400 bg-orange-500/10", ring: "border-orange-500/40" },
  PREMIUMPLUS: { label: "Premium Plus", color: "text-purple-300 bg-purple-500/10", ring: "border-purple-500/40" },
};

function fmtDate(d) {
  // The Nepal calendar day, not the browser's own — see utils/dates.js.
  return formatDateOnly(d);
}

/* ─── Free / Premium / Premium Plus comparison — informational only, no
     payment gateway yet, so no "Buy" buttons: a coupon code (admin-issued
     or earned via referral) is the only way to move a tier up right now.
     On the viewer's own current tier, each limit line shows their actual
     usage against it (e.g. "2 of 2 business profiles") instead of just the
     number, so it's immediately clear whether upgrading would help them. */
function PlanComparison({ effectivePlan, usage }) {
  const plans = [
    { key: "FREE", features: ["2 business profiles", "1 staff member", "Core sales & inventory"] },
    { key: "PREMIUM", features: ["5 business profiles", "3 staff members", "Bulk import/export", "Priority support"] },
    { key: "PREMIUMPLUS", features: ["Unlimited business profiles", "5 staff members", "Everything in Premium"] },
  ];

  const usageFor = (label, isCurrent) => {
    if (!isCurrent || !usage) return null;
    if (label.includes("business profile")) return { count: usage.business_count, limit: usage.business_limit };
    if (label.includes("staff member") && usage.staff_limit !== undefined) return { count: usage.staff_count, limit: usage.staff_limit };
    return null;
  };

  return (
    <div className="grid gap-3 sm:grid-cols-3">
      {plans.map(({ key, features }) => {
        const meta = PLAN_META[key];
        const isCurrent = effectivePlan === key;
        return (
          <div
            key={key}
            className={`rounded-2xl border-2 p-4 ${isCurrent ? meta.ring + " bg-navy-900" : "border-navy-800 bg-navy-950"}`}
          >
            <div className="mb-2 flex items-center justify-between">
              <span className={`inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1 text-xs font-bold ${meta.color}`}>
                {key !== "FREE" && <Crown className="h-3 w-3" />} {meta.label}
              </span>
              {isCurrent && <span className="text-[10px] font-semibold text-green-400">CURRENT</span>}
            </div>
            <ul className="space-y-1.5">
              {features.map((f) => {
                const u = usageFor(f, isCurrent);
                const atLimit = u && u.limit !== null && u.count >= u.limit;
                return (
                  <li key={f} className={`flex items-start gap-1.5 text-xs ${atLimit ? "text-orange-400 font-medium" : "text-navy-400"}`}>
                    <Check className={`mt-0.5 h-3 w-3 shrink-0 ${atLimit ? "text-orange-400" : "text-navy-600"}`} />
                    {u ? `${f} — you're using ${u.count} of ${u.limit}` : f}
                  </li>
                );
              })}
            </ul>
          </div>
        );
      })}
    </div>
  );
}

export default function UpgradePlanPage() {
  const navigate = useNavigate();
  const { currentBusiness, user } = useAuth();

  const [subscription, setSubscription] = useState(null);
  const [referral, setReferral] = useState(null);
  const [loading, setLoading] = useState(true);

  const [couponCode, setCouponCode] = useState("");
  const [applying, setApplying] = useState(false);
  const [couponError, setCouponError] = useState("");
  const [couponSuccess, setCouponSuccess] = useState("");

  const [linkCopied, setLinkCopied] = useState(false);

  const load = useCallback(() => {
    setLoading(true);
    Promise.all([billingApi.subscription(), billingApi.referral()])
      .then(([sub, ref]) => {
        setSubscription(sub.data);
        setReferral(ref.data);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  useEffect(load, [load]);

  const applyCoupon = async (e) => {
    e?.preventDefault();
    if (!couponCode.trim()) return;
    setApplying(true);
    setCouponError("");
    setCouponSuccess("");
    try {
      const { data } = await billingApi.applyCoupon(couponCode.trim());
      setCouponSuccess(data.message || "Coupon applied!");
      setCouponCode("");
      load();
    } catch (err) {
      setCouponError(err.response?.data?.message || "Could not apply this coupon.");
    } finally {
      setApplying(false);
    }
  };

  const copyReferralLink = async () => {
    if (!referral?.referral_link) return;
    try {
      await navigator.clipboard.writeText(referral.referral_link);
      setLinkCopied(true);
      setTimeout(() => setLinkCopied(false), 2000);
    } catch {
      // Clipboard API unavailable — the link is still visible/selectable.
    }
  };

  const whatsappShareUrl = referral?.referral_link
    ? `https://wa.me/?text=${encodeURIComponent(
        `I'm using Bewosai to manage my business. Join using my referral link and get 1 month Premium free:\n\n${referral.referral_link}

Or enter my code ${referral.referral_code} when creating your business.`,
      )}`
    : null;

  if (loading) {
    return (
      <div className="flex justify-center py-20">
        <Loader className="h-6 w-6 animate-spin text-orange-500" />
      </div>
    );
  }

  const effectivePlan = subscription?.effective_plan || "FREE";
  const meta = PLAN_META[effectivePlan] || PLAN_META.FREE;

  // Personalized nudge — only shown when this user has actually hit a real
  // limit, rather than generic "go Premium" copy everyone sees regardless
  // of whether upgrading would change anything for them.
  const atBusinessLimit = subscription?.business_limit !== null && subscription?.business_count >= subscription?.business_limit;
  const atStaffLimit = subscription?.staff_limit !== null && subscription?.staff_limit !== undefined && subscription?.staff_count >= subscription?.staff_limit;

  return (
    <div>
      <button
        onClick={() => navigate("/settings")}
        className="mb-4 flex items-center gap-1.5 text-sm text-navy-400 hover:text-white transition"
      >
        <ArrowLeft className="h-4 w-4" /> Back to Settings
      </button>

      <PageHeader
        title="Upgrade Plan"
        subtitle={`Your account's subscription (${user?.email || user?.phone || "this account"}) — covers every business you own, including ${currentBusiness?.name || "this one"}`}
      />

      {(atBusinessLimit || atStaffLimit) && effectivePlan !== "PREMIUMPLUS" && (
        <div className="mb-5 flex items-start gap-3 rounded-2xl border border-orange-500/30 bg-orange-500/5 p-4">
          <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-orange-400" />
          <div>
            <p className="text-sm font-semibold text-white">
              {atBusinessLimit && atStaffLimit
                ? "You've reached both your business profile and staff limits"
                : atBusinessLimit
                ? `You're using all ${subscription.business_limit} of your business profiles`
                : `You're using all ${subscription.staff_limit} staff slots on this business`}
            </p>
            <p className="mt-0.5 text-xs text-navy-400">Upgrade below to unlock more.</p>
          </div>
        </div>
      )}

      <div className="space-y-5">
        {/* Current plan */}
        <SectionCard title="Your Plan">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <div className={`flex h-11 w-11 items-center justify-center rounded-xl ${meta.color}`}>
                <Crown className="h-5 w-5" />
              </div>
              <div>
                <p className="text-lg font-bold text-white">{meta.label}</p>
                {subscription?.active_subscription ? (
                  <p className="text-xs text-navy-400">
                    Active until {fmtDate(subscription.active_subscription.end_date)}
                    {subscription.active_subscription.source === "REFERRAL" ? " · from a referral reward" : " · from a coupon"}
                  </p>
                ) : subscription?.active_license ? (
                  <p className="text-xs text-navy-400">Active until {fmtDate(subscription.license_expiry)} · licensed</p>
                ) : (
                  <p className="text-xs text-navy-400">Upgrade with a coupon or by referring a friend below</p>
                )}
              </div>
            </div>
          </div>
          <div className="mt-4">
            <PlanComparison effectivePlan={effectivePlan} usage={subscription} />
          </div>
          <p className="mt-3 text-xs text-navy-500">
            Want to buy Premium or Premium Plus directly?{" "}
            <a href="mailto:bewosai@gmail.com" className="font-medium text-orange-400 hover:text-orange-300">
              Email us
            </a>{" "}
            and we'll set you up with a coupon.
          </p>
        </SectionCard>

        {/* Apply coupon */}
        <SectionCard title="Have a Coupon?">
          <form onSubmit={applyCoupon} className="flex flex-wrap items-end gap-3">
            <div className="min-w-0 flex-1">
              <label className="mb-1 block text-xs font-semibold text-navy-400">6-character code</label>
              <input
                value={couponCode}
                onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                placeholder="A7K4P2"
                maxLength={6}
                className="w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm font-mono uppercase tracking-widest text-white outline-none placeholder:text-navy-600 placeholder:tracking-widest focus:border-orange-500"
              />
            </div>
            <PrimaryButton type="submit" disabled={applying || !couponCode.trim()}>
              {applying ? "Applying…" : <><Ticket className="h-4 w-4" /> Apply Coupon</>}
            </PrimaryButton>
          </form>
          {couponError && (
            <p className="mt-3 flex items-center gap-1.5 text-xs text-red-400"><AlertCircle className="h-3.5 w-3.5" /> {couponError}</p>
          )}
          {couponSuccess && (
            <p className="mt-3 flex items-center gap-1.5 text-xs text-green-400"><Check className="h-3.5 w-3.5" /> {couponSuccess}</p>
          )}
        </SectionCard>

        {/* Refer & Earn */}
        <SectionCard title="Refer & Earn">
          <div className="mb-4 flex items-start gap-3 rounded-xl border border-orange-500/20 bg-orange-500/5 px-4 py-3">
            <Gift className="mt-0.5 h-5 w-5 shrink-0 text-orange-400" />
            <p className="text-sm text-navy-300">
              Invite a friend to Bewosai — <span className="font-semibold text-white">you both get 1 month Premium</span> once
              they sign up and verify their account.
            </p>
          </div>

          <label className="mb-1 block text-xs font-semibold text-navy-400">Your referral link</label>
          <div className="flex items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5">
            <input
              readOnly
              value={referral?.referral_link || ""}
              onFocus={(e) => e.target.select()}
              className="w-full truncate bg-transparent text-xs text-navy-300 outline-none"
            />
            <button
              type="button"
              onClick={copyReferralLink}
              className="flex shrink-0 items-center gap-1 rounded-lg bg-orange-500 px-2.5 py-1.5 text-xs font-semibold text-white transition hover:bg-orange-400"
            >
              <Copy className="h-3 w-3" /> {linkCopied ? "Copied!" : "Copy"}
            </button>
            {whatsappShareUrl && (
              <a
                href={whatsappShareUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="flex shrink-0 items-center gap-1 rounded-lg border border-navy-700 px-2.5 py-1.5 text-xs font-semibold text-navy-300 transition hover:border-green-500/50 hover:text-green-400"
              >
                <MessageCircle className="h-3 w-3" /> WhatsApp
              </a>
            )}
          </div>

          <div className="mt-4 flex items-center gap-4">
            <div className="flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-navy-500" />
              <span className="text-sm text-navy-300">
                <span className="font-bold text-white">{referral?.total_referrals ?? 0}</span> successful referral{referral?.total_referrals === 1 ? "" : "s"}
              </span>
            </div>
          </div>

          {referral?.rewards?.length > 0 && (
            <div className="mt-4 space-y-2">
              <p className="text-xs font-semibold text-navy-400">Referral History</p>
              {referral.rewards.map((r) => (
                <div key={r.id} className="flex items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-3 py-2.5">
                  <div className="flex items-center gap-2">
                    {r.status === "REWARDED" ? (
                      <Sparkles className="h-4 w-4 text-green-400" />
                    ) : (
                      <div className="h-2 w-2 rounded-full bg-navy-600" />
                    )}
                    <span className="text-sm text-white">{r.referred_business_name}</span>
                  </div>
                  <span className={`text-xs font-medium ${r.status === "REWARDED" ? "text-green-400" : "text-navy-500"}`}>
                    {r.status === "REWARDED" ? "Premium rewarded" : r.status.charAt(0) + r.status.slice(1).toLowerCase()}
                  </span>
                </div>
              ))}
            </div>
          )}
        </SectionCard>
      </div>
    </div>
  );
}
