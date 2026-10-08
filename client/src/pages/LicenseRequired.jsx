import { useState } from "react";
import { useNavigate } from "react-router-dom";
import bewosaiLogo from "../assessts/images/bewosai.png";
import { KeyRound, Check, AlertCircle, LogOut, Crown } from "lucide-react";
import PaymentModal from "../components/billing/PaymentModal";
import { PLAN_PRICES } from "../constants/payments";
import { billing as billingApi, licenses as licensesApi } from "../api";
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
// Premium coupon codes are 6 characters (billing.models.COUPON_CODE_LENGTH),
// so one box can take either and send it to the right endpoint.
const COUPON_LENGTH = 6;
const isValidLength = (c) => c.length === CODE_LENGTH || c.length === COUPON_LENGTH;

// What the trial-ended screen offers first: pick a plan, pay by QR (PaymentModal).
const PLANS = [
  { key: "PREMIUM", label: "Premium", features: ["5 business profiles", "5 staff members per business", "Bulk import/export"] },
  { key: "PREMIUMPLUS", label: "Premium Plus", features: ["5 business profiles", "5 staff members per business", "Everything in Premium"] },
];

export default function LicenseRequiredPage() {
  const navigate = useNavigate();
  const { logout, refreshBusinesses, user, currentBusiness } = useAuth();
  const [payingFor, setPayingFor] = useState(null); // plan whose QR codes are open
  const { refresh: refreshLicense } = useLicense();
  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [activated, setActivated] = useState(null); // { expiry_date } or { coupon_message }

  const handleActivate = async (e) => {
    e.preventDefault();
    const trimmed = code.trim().toUpperCase();
    if (!isValidLength(trimmed)) {
      setError(`Enter the full code — ${COUPON_LENGTH} characters for a coupon, ${CODE_LENGTH} for a license.`);
      return;
    }
    setLoading(true);
    setError("");
    try {
      if (trimmed.length === COUPON_LENGTH) {
        const { data } = await billingApi.applyCoupon(trimmed);
        setActivated({ coupon_message: data.message });
        refreshBusinesses();
      } else {
        const { data } = await licensesApi.activate(trimmed);
        setActivated(data.license);
      }
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
        <div className={`w-full ${activated ? "max-w-sm" : "max-w-2xl"}`}>
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
                <h2 className="text-xl font-bold text-white">
                  {activated.coupon_message ? "Premium Activated" : "License Activated Successfully"}
                </h2>
                {activated.coupon_message ? (
                  <p className="mt-2 text-sm text-navy-400">{activated.coupon_message}</p>
                ) : (
                  <p className="mt-2 text-sm text-navy-400">
                    Premium access is active until{" "}
                    <span className="font-semibold text-white">
                      {formatExpiryDate(activated.expiry_date)}
                    </span>
                    .
                  </p>
                )}
                <button
                  onClick={() => navigate("/dashboard", { replace: true })}
                  className="mt-6 flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-4 text-base font-bold text-white transition hover:bg-orange-400 active:bg-orange-600"
                >
                  Continue to Bewosai
                </button>
              </div>
            ) : (
              <>
                <div className="mb-5 text-center">
                  <h2 className="text-xl font-bold text-white">Your free trial has ended</h2>
                  <p className="mt-2 text-sm text-navy-400">Choose a plan to keep using Bewosai.</p>
                </div>

                <div className="grid gap-3 sm:grid-cols-2">
                  {PLANS.map(p => (
                    <div key={p.key} className="flex flex-col rounded-2xl border-2 border-orange-500/30 bg-navy-950 p-4">
                      <span className="inline-flex w-fit items-center gap-1.5 rounded-lg bg-orange-500/10 px-2.5 py-1 text-xs font-bold text-orange-400">
                        <Crown className="h-3 w-3" /> {p.label}
                      </span>
                      <p className="mt-2 text-2xl font-extrabold text-white">
                        Rs {PLAN_PRICES[p.key].amount.toLocaleString("en-IN")}
                        <span className="text-sm font-medium text-navy-400"> / {PLAN_PRICES[p.key].period}</span>
                      </p>
                      <ul className="mt-2 flex-1 space-y-1 text-xs text-navy-400">
                        {p.features.map(f => (
                          <li key={f} className="flex items-center gap-1.5"><Check className="h-3 w-3 text-navy-500" /> {f}</li>
                        ))}
                      </ul>
                      <button type="button" onClick={() => setPayingFor(p.key)}
                        className="mt-3 w-full rounded-xl bg-orange-500 py-2.5 text-sm font-bold text-white hover:bg-orange-400">
                        Upgrade to {p.label}
                      </button>
                    </div>
                  ))}
                </div>

                <div className="mx-auto mt-6 max-w-sm">
                <div className="mb-3 flex items-center gap-2 text-sm text-navy-300">
                  <KeyRound className="h-4 w-4 text-orange-400" />
                  Already paid? Enter the coupon code we sent you (or a license code):
                </div>
                <form onSubmit={handleActivate} className="space-y-4">
                  <input
                    value={code}
                    onChange={(e) => {
                      setError("");
                      setCode(e.target.value.toUpperCase().slice(0, COUPON_LENGTH));
                    }}
                    placeholder="A7K9P"
                    maxLength={COUPON_LENGTH}
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
                    disabled={loading || !isValidLength(code)}
                    className="flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-4 text-base font-bold text-white transition hover:bg-orange-400 active:bg-orange-600 disabled:opacity-60"
                  >
                    {loading ? "Activating…" : "Activate Premium"}
                  </button>
                </form>

                </div>

                {payingFor && (
                  <PaymentModal plan={payingFor} userEmail={user?.email} businessName={currentBusiness?.name}
                    onClose={() => setPayingFor(null)} />
                )}

                <p className="mt-5 text-center text-xs text-navy-500">
                  Need help? Please contact us.
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
