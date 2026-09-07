import { useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import bewosaiLogo from "../assessts/images/bewosai.png";

/* ─── Staff login-link landing page — "click this link to open the app as
     this staff member." No form, no OTP: the token in the URL is the
     credential, exchanged for a session on mount. ─── */
export default function StaffLoginPage() {
  const { token } = useParams();
  const navigate = useNavigate();
  const { loginWithStaffLink } = useAuth();
  const [error, setError] = useState("");
  const ran = useRef(false);

  useEffect(() => {
    if (ran.current) return;
    ran.current = true;
    (async () => {
      const res = await loginWithStaffLink(token);
      if (res.ok) {
        // Staff accounts are always business-type — never personal — so
        // this doesn't need to branch on user.account_type the way the
        // OTP flow does.
        navigate("/dashboard", { replace: true });
      } else {
        setError(res.error);
      }
    })();
  }, [token]);

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-navy-950 px-4 text-center">
      <img src={bewosaiLogo} alt="Bewosai" className="mb-6 h-16 w-16 rounded-2xl object-cover shadow-xl shadow-orange-500/20 ring-2 ring-orange-500/30" />
      {error ? (
        <>
          <p className="mb-2 text-lg font-bold text-white">Can't sign in</p>
          <p className="max-w-sm text-sm text-navy-400">{error}</p>
          <button
            onClick={() => navigate("/login")}
            className="mt-5 rounded-2xl bg-orange-500 px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-orange-400"
          >
            Go to login
          </button>
        </>
      ) : (
        <p className="text-sm text-navy-400 animate-pulse">Signing you in…</p>
      )}
    </div>
  );
}
