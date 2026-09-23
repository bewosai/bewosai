import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import bewosaiLogo from "../assessts/images/bewosai.png";
import { User, Building2, ArrowRight, ArrowLeft, RefreshCw, Check } from "lucide-react";
import { OTPInput, ProfileCard, Steps } from "../components/auth/AuthWidgets";

/* ─── Verify OTP page — Step 2: OTP entry, Step 3: profile setup ─────────────────────── */
export default function VerifyOtpPage() {
  const { sendOtp, verifyOtp, setAccountType, loading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const identifier = location.state?.identifier;
  // Phone login/signup temporarily disabled (2026-09-16) — identifier is
  // always an email now, so this always resolves to false. Kept commented
  // out (not deleted) for easy restore; see sparrow_sms_nepal_only memory.
  // const isPhone = identifier ? !identifier.includes("@") : false;
  const isPhone = false;
  const initialUserExists = location.state?.userExists ?? false;
  // The backend's own message.
  const initialMessage = location.state?.message;

  const [step, setStep] = useState(2); // 2=otp, 3=profile (new users only)
  const [otp, setOtp] = useState("");
  const [remember, setRemember] = useState(false);
  const [resendTimer, setResendTimer] = useState(60);
  const [error, setError] = useState("");
  const [info, setInfo] = useState(
    initialMessage || (initialUserExists ? `Welcome back! OTP sent to ${identifier}` : `OTP sent to ${identifier}`)
  );
  const [isNewUser, setIsNewUser] = useState(false);
  const [selectedProfile, setSelectedProfile] = useState("");

  // Reached directly (e.g. page refresh) with no identifier in state — nothing to verify
  useEffect(() => {
    if (!identifier) navigate("/login", { replace: true });
  }, [identifier]);

  useEffect(() => {
    if (resendTimer <= 0) return;
    const t = setInterval(() => setResendTimer((p) => Math.max(0, p - 1)), 1000);
    return () => clearInterval(t);
  }, [resendTimer]);

  const clear = () => { setError(""); setInfo(""); };

  /* ── Step 2 → Verify OTP ── */
  const handleVerify = async (e) => {
    e?.preventDefault();
    clear();
    const digits = otp.replace(/\s/g, "");
    if (digits.length < 6) { setError("Enter the complete 6-digit OTP."); return; }
    const res = await verifyOtp(identifier, digits, remember);
    if (res.ok) {
      if (res.isPlatformAdmin) {
        // Every platform admin lands on Super Admin straight after signing
        // in — previously only true when they had no business of their own,
        // which meant "is_platform_admin didn't take effect" and "landed on
        // a normal dashboard instead" looked identical from the outside.
        // They can still reach their own business from Super Admin's sidebar.
        navigate("/superadmin", { replace: true });
      } else if (res.needsProfileSetup) {
        // New user — must pick profile
        setIsNewUser(true);
        setStep(3);
      } else {
        // Existing user → go directly to their dashboard
        const count = res.businesses?.length ?? 0;
        const dest = res.accountType === "personal"
          ? "/personal/dashboard"
          : count === 0 ? "/create-business"
          : count > 1 ? "/select-business"
          : "/dashboard";
        navigate(dest, { replace: true });
      }
    } else {
      setError(res.error);
      setOtp("");
    }
  };

  /* ── Step 3 → Choose profile type ── */
  const handleProfileSetup = async () => {
    if (!selectedProfile) { setError("Please choose your account type."); return; }
    clear();
    const res = await setAccountType(selectedProfile);
    if (res.ok) {
      const dest = res.accountType === "personal"
        ? "/personal/dashboard"
        : "/create-business";
      navigate(dest, { replace: true });
    } else {
      setError(res.error);
    }
  };

  const handleResend = async () => {
    if (resendTimer > 0) return;
    clear();
    const res = await sendOtp(identifier);
    if (res.ok) {
      setResendTimer(60);
      setInfo(res.message || "New OTP sent.");
    } else {
      setError(res.error);
    }
  };

  if (!identifier) return null;

  return (
    <div className="flex min-h-screen flex-col bg-navy-950">
      <div className="flex flex-1 flex-col items-center justify-center px-4 py-8 sm:py-12">
        <div className="w-full max-w-sm">

          {/* Logo */}
          <div className="mb-8 flex flex-col items-center gap-3 text-center">
            <div className="relative">
              <img
                src={bewosaiLogo}
                alt="Bewosai"
                className="h-18 w-18 rounded-3xl object-cover shadow-xl shadow-orange-500/20 ring-2 ring-orange-500/30"
                style={{ height: 72, width: 72 }}
              />
              <div className="absolute -bottom-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full bg-orange-500 shadow-md">
                <Check className="h-3.5 w-3.5 text-white" />
              </div>
            </div>
            <div>
              <h1 className="text-2xl font-extrabold text-white">Bewosai</h1>
              <p className="text-xs text-navy-400 mt-0.5">Smart Business Suite</p>
            </div>
          </div>

          {/* Card */}
          <div className="rounded-3xl border border-navy-800 bg-navy-900/80 px-6 py-7 shadow-2xl backdrop-blur-sm">

            <Steps
              current={step}
              steps={isNewUser ? ["Email", "Verify", "Profile"] : ["Email", "Verify"]}
            />

            {/* Messages */}
            {error && (
              <div className="mb-4 rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-2.5 text-sm text-red-400">
                {error}
              </div>
            )}
            {info && !error && (
              <div className="mb-4 rounded-xl border border-green-500/30 bg-green-500/10 px-4 py-2.5 text-sm text-green-400">
                {info}
              </div>
            )}

            {/* ── Step 2: OTP ── */}
            {step === 2 && (
              <form onSubmit={handleVerify}>
                <button
                  type="button"
                  onClick={() => navigate(location.key === "default" ? "/login" : -1)}
                  className="mb-4 flex items-center gap-1.5 text-sm text-navy-400 hover:text-white transition"
                >
                  <ArrowLeft className="h-4 w-4" /> Back
                </button>

                <div className="mb-5 text-center">
                  <h2 className="text-xl font-bold text-white">
                    {isPhone ? "Check your phone" : "Check your email"}
                  </h2>
                  <p className="mt-1.5 text-sm text-navy-400">
                    {isPhone ? (
                      // Backend's own message covers both cases: delivered by
                      // SMS ("OTP sent to your phone") or, for a non-Nepal
                      // number, "sent to j***@example.com instead" — showing
                      // the raw identifier here would leak the phone number
                      // right back or contradict an email fallback.
                      initialMessage || "We sent a 6-digit code to your phone."
                    ) : (
                      <>We sent a 6-digit code to<br /><span className="font-semibold text-white">{identifier}</span></>
                    )}
                  </p>
                </div>

                <OTPInput value={otp} onChange={setOtp} disabled={loading} />

                {/* Remember device */}
                <label className="mt-5 flex cursor-pointer items-center gap-3 rounded-2xl border border-navy-700 bg-navy-950/60 px-4 py-3">
                  <div
                    onClick={() => setRemember(!remember)}
                    className={`flex h-5 w-5 shrink-0 items-center justify-center rounded-md border-2 transition ${
                      remember ? "border-orange-500 bg-orange-500" : "border-navy-600"
                    }`}
                  >
                    {remember && <Check className="h-3 w-3 text-white" />}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-white">Keep me signed in for 30 days</p>
                    <p className="text-xs text-navy-500">Skip OTP on this device</p>
                  </div>
                </label>

                <button
                  type="submit"
                  disabled={loading || otp.replace(/\s/g, "").length < 6}
                  className="mt-4 flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-4 text-base font-bold text-white transition hover:bg-orange-400 active:bg-orange-600 disabled:opacity-60"
                >
                  {loading ? <span className="animate-pulse">Verifying…</span> : <>Verify & Continue <ArrowRight className="h-4 w-4" /></>}
                </button>

                <button
                  type="button"
                  onClick={handleResend}
                  disabled={resendTimer > 0 || loading}
                  className="mt-3 flex w-full items-center justify-center gap-1.5 text-sm text-navy-400 transition hover:text-orange-400 disabled:opacity-40"
                >
                  <RefreshCw className="h-3.5 w-3.5" />
                  {resendTimer > 0 ? `Resend in ${resendTimer}s` : "Resend OTP"}
                </button>
              </form>
            )}

            {/* ── Step 3: Profile selection (new users only) ── */}
            {step === 3 && (
              <div>
                <div className="mb-5 text-center">
                  <h2 className="text-xl font-bold text-white">Choose your profile</h2>
                  <p className="mt-1.5 text-sm text-navy-400">
                    Select once — this sets up your workspace
                  </p>
                </div>

                <div className="space-y-3">
                  <ProfileCard
                    label="Business"
                    description="Complete business management for shops, companies & teams"
                    features={["Sales & Invoices", "Inventory", "Staff & Roles", "Reports", "Purchases"]}
                    icon={Building2}
                    iconColor="bg-orange-500/15 text-orange-500"
                    selected={selectedProfile === "business"}
                    onSelect={() => setSelectedProfile("business")}
                  />
                  <ProfileCard
                    label="Personal Finance"
                    description="Track personal income, expenses and budgets"
                    features={["Income tracking", "Expenses", "Budget", "Reports"]}
                    icon={User}
                    iconColor="bg-blue-500/15 text-blue-500"
                    selected={selectedProfile === "personal"}
                    onSelect={() => setSelectedProfile("personal")}
                  />
                </div>

                <button
                  onClick={handleProfileSetup}
                  disabled={!selectedProfile || loading}
                  className="mt-5 flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-4 text-base font-bold text-white transition hover:bg-orange-400 active:bg-orange-600 disabled:opacity-60"
                >
                  {loading ? <span className="animate-pulse">Setting up…</span> : <>Get Started <ArrowRight className="h-4 w-4" /></>}
                </button>

                <p className="mt-3 text-center text-xs text-navy-500">
                  You can always add another workspace later
                </p>
              </div>
            )}
          </div>

          <p className="mt-5 text-center text-xs text-navy-500">
            By continuing you agree to Bewosai's Terms of Service
          </p>
        </div>
      </div>
    </div>
  );
}
