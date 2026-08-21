import { createContext, useContext, useState, useCallback } from "react";
import { auth as authApi } from "../api";

const AuthContext = createContext(null);

function stored(key) {
  try { return JSON.parse(localStorage.getItem(key)); } catch { return null; }
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => stored("user"));
  const [businesses, setBusinesses] = useState(() => stored("businesses") || []);
  const [currentBusiness, setCurrentBusiness] = useState(() => stored("current_business"));
  const [loading, setLoading] = useState(false);

  const isLoggedIn = !!user && !!localStorage.getItem("access");

  /** Step 1: send OTP — no account type needed */
  const sendOtp = useCallback(async (email, isSignup = false) => {
    setLoading(true);
    try {
      const { data } = await authApi.sendOtp(email, isSignup);
      return {
        ok: true,
        userExists: data.user_exists,
      };
    } catch (err) {
      return {
        ok: false,
        error: err.response?.data?.message || err.response?.data?.detail || "Failed to send OTP.",
        userExists: err.response?.data?.user_exists || false,
      };
    } finally {
      setLoading(false);
    }
  }, []);

  /** Step 2: verify OTP — returns is_new_user + needs_profile_setup */
  const verifyOtp = useCallback(async (email, code, remember) => {
    setLoading(true);
    try {
      const { data } = await authApi.verifyOtp(email, code, remember);

      localStorage.setItem("access", data.access);
      localStorage.setItem("refresh", data.refresh);
      localStorage.setItem("user", JSON.stringify(data.user));
      localStorage.setItem("businesses", JSON.stringify(data.businesses));

      setUser(data.user);
      setBusinesses(data.businesses);

      // Auto-select the one business if available
      if (data.businesses.length === 1) {
        const biz = data.businesses[0];
        localStorage.setItem("current_business", JSON.stringify(biz));
        localStorage.setItem("business_id", String(biz.id));
        setCurrentBusiness(biz);
      }

      return {
        ok: true,
        isNew: data.is_new_user,
        needsProfileSetup: data.needs_profile_setup,
        accountType: data.user.account_type,
        businesses: data.businesses,
      };
    } catch (err) {
      return { ok: false, error: err.response?.data?.message || err.response?.data?.detail || "OTP verification failed." };
    } finally {
      setLoading(false);
    }
  }, []);

  /** Step 3 (new users): choose Personal or Business profile */
  const setAccountType = useCallback(async (accountType) => {
    setLoading(true);
    try {
      const { data } = await authApi.setAccountType(accountType);

      // Update stored user with new account_type
      const updatedUser = { ...stored("user"), account_type: data.user.account_type };
      localStorage.setItem("user", JSON.stringify(updatedUser));
      localStorage.setItem("businesses", JSON.stringify(data.businesses));
      setUser(updatedUser);
      setBusinesses(data.businesses);

      if (data.businesses.length === 1) {
        const biz = data.businesses[0];
        localStorage.setItem("current_business", JSON.stringify(biz));
        localStorage.setItem("business_id", String(biz.id));
        setCurrentBusiness(biz);
      }

      return { ok: true, accountType: data.user.account_type, businesses: data.businesses };
    } catch (err) {
      return { ok: false, error: err.response?.data?.message || err.response?.data?.detail || "Failed to set account type." };
    } finally {
      setLoading(false);
    }
  }, []);

  const selectBusiness = useCallback((biz) => {
    localStorage.setItem("current_business", JSON.stringify(biz));
    localStorage.setItem("business_id", String(biz.id));
    setCurrentBusiness(biz);
  }, []);

  /** After creating a business: add it to the switch-business list (not
   * just select it) — selectBusiness alone left newly created businesses
   * missing from Select Business / the Topbar switcher until the next
   * full login, since neither the `businesses` state nor its localStorage
   * copy ever learned about it. */
  const addBusiness = useCallback((biz) => {
    setBusinesses((prev) => {
      const next = [...prev, biz];
      localStorage.setItem("businesses", JSON.stringify(next));
      return next;
    });
    selectBusiness(biz);
  }, [selectBusiness]);

  /** Keeps `businesses` (and the currently selected one, if it's the one
   * that changed) in sync after an edit — e.g. renaming a business in
   * Settings must be reflected in the switcher list too. */
  const updateBusinessInList = useCallback((biz) => {
    setBusinesses((prev) => {
      const next = prev.map((b) => (b.id === biz.id ? biz : b));
      localStorage.setItem("businesses", JSON.stringify(next));
      return next;
    });
    setCurrentBusiness((prev) => {
      if (prev?.id !== biz.id) return prev;
      localStorage.setItem("current_business", JSON.stringify(biz));
      return biz;
    });
  }, []);

  const logout = useCallback(async () => {
    const refresh = localStorage.getItem("refresh");
    try { await authApi.logout(refresh); } catch {}
    localStorage.clear();
    setUser(null);
    setBusinesses([]);
    setCurrentBusiness(null);
  }, []);

  return (
    <AuthContext.Provider value={{
      user, businesses, currentBusiness,
      loading, isLoggedIn,
      sendOtp, verifyOtp, setAccountType, logout, selectBusiness,
      addBusiness, updateBusinessInList,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
