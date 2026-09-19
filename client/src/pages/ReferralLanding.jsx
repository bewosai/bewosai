import { Navigate, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

/** What a shared referral link (/r/CODE) opens. The visitor isn't signed in
 * yet, so the code is remembered (CreateBusiness reads it) and they're sent to
 * sign in — otherwise the code would be lost at the login redirect. Someone
 * already signed in goes straight to creating a business with it. */
export const PENDING_REFERRAL_KEY = "pending_referral";

export default function ReferralLanding() {
  const { code } = useParams();
  const { isLoggedIn } = useAuth();
  const clean = (code || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 10);
  if (clean) {
    try { localStorage.setItem(PENDING_REFERRAL_KEY, clean); } catch { /* private mode — the ?ref= copy below still works */ }
  }
  return <Navigate to={isLoggedIn ? `/create-business?ref=${clean}` : "/login"} replace />;
}
