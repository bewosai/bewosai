import { createContext, useContext, useState, useCallback } from "react";
import { auth as authApi } from "../api";

const AuthContext = createContext(null);

function stored(key) {
  try { return JSON.parse(localStorage.getItem(key)); } catch { return null; }
}

/** The message to show for a failed sign-in call. Prefers what the backend said;
 * otherwise says what actually went wrong — a server that's asleep or restarting
 * (the free host wakes on the first request and can take a minute) is not the
 * same as a wrong code, and used to show the same generic line. */
function signInError(err, fallback) {
  const data = err.response?.data;
  const fromServer = data?.message || data?.detail;
  if (typeof fromServer === "string" && fromServer) return fromServer;
  if (!err.response) {
    return "Couldn't reach the server. It may be waking up — wait a few seconds and try again.";
  }
  if (err.response.status >= 500) {
    return "The server is busy or restarting. Wait a moment and try again.";
  }
  return fallback;
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => stored("user"));
  const [businesses, setBusinesses] = useState(() => stored("businesses") || []);
  const [currentBusiness, setCurrentBusiness] = useState(() => stored("current_business"));
  const [loading, setLoading] = useState(false);

  const isLoggedIn = !!user && !!localStorage.getItem("access");

  /** Step 1: send OTP — identifier can be an email or (for existing accounts
   * with a phone on file) a phone number; no account type needed yet */
  const sendOtp = useCallback(async (identifier, isSignup = false) => {
    setLoading(true);
    try {
      const { data } = await authApi.sendOtp(identifier, isSignup);
      return {
        ok: true,
        userExists: data.user_exists,
        message: data.message,
      };
    } catch (err) {
      return {
        ok: false,
        error: signInError(err, "Failed to send OTP."),
        userExists: err.response?.data?.user_exists || false,
      };
    } finally {
      setLoading(false);
    }
  }, []);

  /** Shared by every "here's a fresh JWT pair + user" success path (OTP
   * verify, staff login link) — populates both localStorage and this
   * context's state the same way so nothing downstream (ProtectedRoute,
   * the axios interceptor, business switching) needs to know which flow
   * the session came from. */
  const _storeSession = (data) => {
    localStorage.setItem("access", data.access);
    localStorage.setItem("refresh", data.refresh);
    localStorage.setItem("user", JSON.stringify(data.user));
    localStorage.setItem("businesses", JSON.stringify(data.businesses));

    setUser(data.user);
    setBusinesses(data.businesses);

    // Auto-select: the one business if that's all there is, or — with
    // multiple businesses — whichever one this browser last had selected
    // (survives logout via `last_business_id`, see logout() below), so
    // returning users land straight on their dashboard instead of the
    // Select Business picker every time they log back in.
    const lastId = localStorage.getItem("last_business_id");
    const remembered = lastId && data.businesses.find((b) => String(b.id) === lastId);
    const biz = data.businesses.length === 1 ? data.businesses[0] : remembered;
    if (biz) {
      localStorage.setItem("current_business", JSON.stringify(biz));
      localStorage.setItem("business_id", String(biz.id));
      setCurrentBusiness(biz);
    }
  };

  /** Step 2: verify OTP — returns is_new_user + needs_profile_setup */
  const verifyOtp = useCallback(async (identifier, code, remember) => {
    setLoading(true);
    try {
      const { data } = await authApi.verifyOtp(identifier, code, remember);
      _storeSession(data);

      return {
        ok: true,
        isNew: data.is_new_user,
        needsProfileSetup: data.needs_profile_setup,
        accountType: data.user.account_type,
        isPlatformAdmin: !!data.user.is_platform_admin,
        businesses: data.businesses,
      };
    } catch (err) {
      return { ok: false, error: signInError(err, "OTP verification failed.") };
    } finally {
      setLoading(false);
    }
  }, []);

  /** Staff "click this link to open the app as this staff member" login —
   * see accounts.views.StaffLoginView. No OTP/email involved; the link's
   * token is the sole credential. */
  const loginWithStaffLink = useCallback(async (token) => {
    setLoading(true);
    try {
      const { data } = await authApi.staffLogin(token);
      _storeSession(data);
      return { ok: true };
    } catch (err) {
      return { ok: false, error: err.response?.data?.message || "This login link is invalid or has been revoked." };
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
    localStorage.setItem("last_business_id", String(biz.id));
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

  /** Fiscal-year close: the old business is archived server-side and a
   * fresh one is created in its place (see accounts.CloseFiscalYearView) —
   * swap it in the switcher list rather than just adding the new one, or
   * the now-archived business would linger there until the next full login. */
  const replaceBusiness = useCallback((oldId, newBiz) => {
    setBusinesses((prev) => {
      const next = [...prev.filter((b) => b.id !== oldId), newBiz];
      localStorage.setItem("businesses", JSON.stringify(next));
      return next;
    });
    selectBusiness(newBiz);
  }, [selectBusiness]);

  /** Re-reads the signed-in account from the server. The copy saved at sign-in
   * goes stale when something changes it afterwards — e.g. an account made a
   * Super Admin while it was already signed in. Returns the fresh user, or null
   * if it couldn't be fetched. */
  const refreshUser = useCallback(async () => {
    try {
      const { data } = await authApi.me();
      localStorage.setItem("user", JSON.stringify(data));
      setUser(data);
      return data;
    } catch {
      return null;
    }
  }, []);

  const logout = useCallback(async () => {
    const refresh = localStorage.getItem("refresh");
    const lastBusinessId = localStorage.getItem("last_business_id");
    try { await authApi.logout(refresh); } catch {}
    localStorage.clear();
    // Preserved deliberately (see _storeSession) so the next login on this
    // browser can auto-restore the same business instead of re-prompting.
    if (lastBusinessId) localStorage.setItem("last_business_id", lastBusinessId);
    setUser(null);
    setBusinesses([]);
    setCurrentBusiness(null);
  }, []);

  return (
    <AuthContext.Provider value={{
      user, businesses, currentBusiness,
      loading, isLoggedIn,
      sendOtp, verifyOtp, setAccountType, logout, selectBusiness, refreshUser,
      addBusiness, updateBusinessInList, replaceBusiness, loginWithStaffLink,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
