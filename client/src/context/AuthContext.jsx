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

  /* send OTP */
  const sendOtp = useCallback(async (email, accountType) => {
    setLoading(true);
    try {
      const { data } = await authApi.sendOtp(email, accountType);
      return { ok: true, otp: data.otp }; // otp only in dev mode
    } catch (err) {
      return { ok: false, error: err.response?.data?.error || "Failed to send OTP." };
    } finally {
      setLoading(false);
    }
  }, []);

  /* verify OTP → login */
  const verifyOtp = useCallback(async (email, code, accountType, remember) => {
    setLoading(true);
    try {
      const { data } = await authApi.verifyOtp(email, code, accountType, remember);

      localStorage.setItem("access", data.access);
      localStorage.setItem("refresh", data.refresh);
      localStorage.setItem("user", JSON.stringify(data.user));
      localStorage.setItem("businesses", JSON.stringify(data.businesses));

      setUser(data.user);
      setBusinesses(data.businesses);

      // Auto-select business
      if (data.businesses.length === 1) {
        const biz = data.businesses[0];
        localStorage.setItem("current_business", JSON.stringify(biz));
        localStorage.setItem("business_id", biz.id);
        setCurrentBusiness(biz);
      } else if (data.businesses.length === 0 && accountType === "personal") {
        // personal users get auto-business from backend; refresh
        const { data: bData } = await authApi.businesses();
        const bizList = bData.results ?? bData;
        if (bizList.length > 0) {
          localStorage.setItem("current_business", JSON.stringify(bizList[0]));
          localStorage.setItem("business_id", bizList[0].id);
          setCurrentBusiness(bizList[0]);
        }
      }

      return {
        ok: true,
        accountType: data.user.account_type,
        isNew: data.is_new_user,
        businesses: data.businesses,
      };
    } catch (err) {
      return { ok: false, error: err.response?.data?.error || "OTP verification failed." };
    } finally {
      setLoading(false);
    }
  }, []);

  const selectBusiness = useCallback((biz) => {
    localStorage.setItem("current_business", JSON.stringify(biz));
    localStorage.setItem("business_id", biz.id);
    setCurrentBusiness(biz);
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
      sendOtp, verifyOtp, logout, selectBusiness,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
