import { createContext, useContext, useState, useEffect, useCallback } from "react";
import { features as featuresApi } from "../api";
import { useAuth } from "./AuthContext";

const FeatureContext = createContext(null);

// Fail open until the first fetch resolves (and if it never does, e.g. the
// user isn't on a business yet) so a slow/failed network call can't lock
// a legitimate user out of the whole app — the backend is still the real
// gate on every write, this only drives what the UI shows.
function stored() {
  try { return JSON.parse(localStorage.getItem("features")) || {}; } catch { return {}; }
}

export function FeatureProvider({ children }) {
  const { currentBusiness, isLoggedIn } = useAuth();
  const [featureMap, setFeatureMap] = useState(stored);
  const [loaded, setLoaded] = useState(false);

  const refresh = useCallback(async () => {
    if (!isLoggedIn) return;
    try {
      const { data } = await featuresApi.effective();
      setFeatureMap(data.features || {});
      localStorage.setItem("features", JSON.stringify(data.features || {}));
    } catch {
      // keep whatever was last cached — see stored() above
    } finally {
      setLoaded(true);
    }
  }, [isLoggedIn]);

  useEffect(() => {
    refresh();
  }, [refresh, currentBusiness?.id]);

  // Unknown keys default to enabled — only features the Super Admin has
  // explicitly registered and disabled should ever block anything.
  const isFeatureEnabled = useCallback(
    (key) => featureMap[key] !== false,
    [featureMap]
  );

  return (
    <FeatureContext.Provider value={{ featureMap, loaded, isFeatureEnabled, refresh }}>
      {children}
    </FeatureContext.Provider>
  );
}

export function useFeatures() {
  return useContext(FeatureContext);
}
