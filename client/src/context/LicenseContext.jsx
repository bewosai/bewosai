import { createContext, useContext, useState, useEffect, useCallback } from "react";
import { licenses as licensesApi } from "../api";
import { useAuth } from "./AuthContext";

const LicenseContext = createContext(null);

// Fail open until the first fetch resolves, same reasoning as FeatureContext
// — a slow/failed network call must never lock out a legitimate user on its
// own. The backend's HasActiveSubscription permission is the real gate on
// every write; this only drives what the UI shows.
export function LicenseProvider({ children }) {
  const { currentBusiness, isLoggedIn } = useAuth();
  const [status, setStatus] = useState(null);
  const [loaded, setLoaded] = useState(false);

  const refresh = useCallback(async () => {
    if (!isLoggedIn || !currentBusiness) return;
    try {
      const { data } = await licensesApi.me();
      setStatus(data);
    } catch {
      // keep whatever was last known rather than assuming locked out
    } finally {
      setLoaded(true);
    }
  }, [isLoggedIn, currentBusiness?.id]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Mid-session signal: refresh() above only runs on login/business-switch,
  // so a trial/license that lapses while the user is already in the app is
  // otherwise invisible until they hit a 403 with no explanation. The axios
  // interceptor (api/index.js) broadcasts this event the moment that
  // happens; flip state immediately for a responsive redirect, then refresh
  // to get the real trial_expiry_date/license payload for the License
  // Required screen to display.
  useEffect(() => {
    const handleSubscriptionRequired = () => {
      setStatus((prev) => ({ ...(prev || {}), has_active_subscription: false }));
      setLoaded(true);
      refresh();
    };
    window.addEventListener("bewosai:subscription-required", handleSubscriptionRequired);
    return () => window.removeEventListener("bewosai:subscription-required", handleSubscriptionRequired);
  }, [refresh]);

  const hasActiveSubscription = status ? status.has_active_subscription : true;

  return (
    <LicenseContext.Provider value={{ status, loaded, hasActiveSubscription, refresh }}>
      {children}
    </LicenseContext.Provider>
  );
}

export function useLicense() {
  return useContext(LicenseContext);
}
