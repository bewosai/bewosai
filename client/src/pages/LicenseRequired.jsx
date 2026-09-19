import { useState } from "react";
import { useNavigate } from "react-router-dom";
import bewosaiLogo from "../assessts/images/bewosai.png";
import { KeyRound, Check, AlertCircle, LogOut } from "lucide-react";
import { licenses as licensesApi } from "../api";
import { useAuth } from "../context/AuthContext";
import { useLicense } from "../context/LicenseContext";
import { nepalYMD } from "../utils/dates";

const FULL_MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];
// The Nepal calendar day, not the browser's own — see utils/dates.js.
const formatExpiryDate = (d) => {
  if (!d) return "—";
  const { y, mo, d: day } = nepalYMD(d);
  return `${FULL_MONTHS[mo - 1]} ${day}, ${y}`;
};

const CODE_LENGTH = 5;

export default function LicenseRequiredPage() {
  const navigate = useNavigate();
  const { logout } = useAuth();
  const { refresh: refreshLicense } = useLicense();
  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [activated, setActivated] = useState(null); // { expiry_date }

  const handleActivate = async (e) => {
    e.preventDefault();
    const trimmed = code.trim().toUpperCase();
    if (trimmed.length !== CODE_LENGTH) {
      setError(`Enter the full ${CODE_LENGTH}-character code.`);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const { data } = await licensesApi.activate(trimmed);
      setActivated(data.license);
      await refreshLicense();
    } catch (err) {
      setError(err.response?.data?.message || "Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen flex-col bg-navy-950">
      <div className="flex flex-1 flex-col items-center justify-center px-4 py-8 sm:py-12">
        <div className="w-full max-w-sm">
          <div className="mb-8 flex flex-col items-center gap-3 text-center">
            <img
              src={bewosaiLogo}
              alt="Bewosai"
              className="rounded-3xl object-cover shadow-xl shadow-orange-500/20 ring-2 ring-orange-500/30"
              style={{ height: 72, width: 72 }}
            />
            <div>
              <h1 className="text-2xl font-extrabold text-white">Bewosai</h1>
              <p className="text-xs text-navy-400 mt-0.5">Smart Business Suite</p>
            </div>
          </div>

          <div className="rounded-3xl border border-navy-800 bg-navy-900/80 px-6 py-7 shadow-2xl backdrop-blur-sm">
            {activated ? (
              <div className="text-center">
                <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-green-500/15">
                  <Check className="h-7 w-7 text-green-400" />
                </div>
                <h2 className="text-xl font-bold text-white">License Activated Successfully</h2>
                <p className="mt-2 text-sm text-navy-400">
                  Premium access is active until{" "}
                  <span className="font-semibold text-white">
                    {formatExpiryDate(activated.expiry_date)}
                  </span>
                  .
                </p>
                <button
                  onClick={() => navigate("/dashboard", { replace: true })}
                  className="mt-6 flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-4 text-base font-bold text-white transition hover:bg-orange-400 active:bg-orange-600"
                >
                  Continue to Bewosai
                </button>
              </div>
            ) : (
              <>
                <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-orange-500/15">
                  <KeyRound className="h-7 w-7 text-orange-400" />
                </div>
                <div className="mb-5 text-center">
                  <h2 className="text-xl font-bold text-white">Premium License Required</h2>
                  <p className="mt-2 text-sm text-navy-400">
                    Your free trial has ended. Enter the license code provided by your administrator to continue.
                  </p>
                </div>

                <form onSubmit={handleActivate} className="space-y-4">
                  <input
                    value={code}
                    onChange={(e) => {
                      setError("");
                      setCode(e.target.value.toUpperCase().slice(0, CODE_LENGTH));
                    }}
                    placeholder="A7K9P"
                    autoFocus
                    maxLength={CODE_LENGTH}
                    className="w-full rounded-2xl border border-navy-700 bg-navy-950 px-4 py-4 text-center text-2xl font-bold tracking-[0.4em] text-white placeholder:text-navy-700 focus:border-orange-500 focus:outline-none"
                  />

                  {error && (
                    <div className="flex items-start gap-2 rounded-xl border border-red-500/30 bg-red-500/10 px-3 py-2.5 text-sm text-red-400">
                      <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
                      <span>{error}</span>
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading || code.length !== CODE_LENGTH}
                    className="flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-4 text-base font-bold text-white transition hover:bg-orange-400 active:bg-orange-600 disabled:opacity-60"
                  >
                    {loading ? "Activating…" : "Activate License"}
                  </button>
                </form>

                <p className="mt-5 text-center text-xs text-navy-500">
                  Need a license? Please contact your administrator.
                </p>

                <button
                  onClick={async () => { await logout(); navigate("/login", { replace: true }); }}
                  className="mx-auto mt-4 flex items-center gap-1.5 text-xs text-navy-500 hover:text-navy-300"
                >
                  <LogOut className="h-3.5 w-3.5" /> Log out
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
