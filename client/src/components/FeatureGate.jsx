import { Lock } from "lucide-react";
import { useFeatures } from "../context/FeatureContext";

/**
 * Blocks a page's content when the Super Admin has switched its feature off
 * (or restricted it to Premium and this business is on Free) — the backend
 * enforces the same key on every write via bewosai.permissions.require_feature,
 * this just keeps the UI from showing a page whose API calls would 403.
 */
export default function FeatureGate({ feature, children }) {
  const { isFeatureEnabled, loaded } = useFeatures();

  if (loaded && !isFeatureEnabled(feature)) {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center gap-3 rounded-2xl border border-navy-800 bg-navy-900/50 p-8 text-center">
        <div className="flex h-14 w-14 items-center justify-center rounded-full bg-navy-800">
          <Lock className="h-6 w-6 text-navy-400" />
        </div>
        <h2 className="text-lg font-bold text-white">This feature is currently unavailable</h2>
        <p className="max-w-sm text-sm text-navy-400">
          It's been switched off for your plan, disabled by the platform admin, or your account
          hasn't been given access to it. Contact your business owner or administrator if you
          believe this is unexpected.
        </p>
      </div>
    );
  }

  return children;
}
