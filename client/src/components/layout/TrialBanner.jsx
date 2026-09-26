import { useNavigate } from "react-router-dom";
import { Crown, ChevronRight } from "lucide-react";
import { useLicense } from "../../context/LicenseContext";
import { todayStr } from "../../utils/dates";

// "Free trial: N days left · Go Premium" — shown only while the business is on
// its free trial with no license or coupon. Opens the Upgrade page, where a
// coupon code activates Premium.
export default function TrialBanner() {
  const navigate = useNavigate();
  const { status } = useLicense() || {};
  const onFreeTrial =
    status?.is_trial_active && !status.is_grandfathered && !status.license &&
    (status.effective_plan || "FREE") === "FREE";
  if (!onFreeTrial) return null;

  const expiry = status.trial_expiry_date;
  const days = expiry
    ? Math.max(0, Math.round((Date.parse(expiry) - Date.parse(todayStr())) / 86400000))
    : null;
  const label = days == null
    ? "You are on the free trial"
    : days === 0 ? "Your free trial ends today" : `Free trial: ${days} day${days === 1 ? "" : "s"} left`;

  return (
    <button
      onClick={() => navigate("/settings/upgrade")}
      className="flex w-full items-center gap-2 border-b border-orange-500/20 bg-orange-500/10 px-4 py-2 text-left text-sm text-orange-300 transition hover:bg-orange-500/15"
    >
      <Crown className="h-4 w-4 shrink-0" />
      <span className="flex-1 font-semibold">{label}</span>
      <span className="font-bold">Go Premium</span>
      <ChevronRight className="h-4 w-4" />
    </button>
  );
}
