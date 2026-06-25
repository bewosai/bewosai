import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import bewosyLogo from "../assessts/images/bewosy.jpeg";
import { User, Building2, ArrowRight, ArrowLeft, RefreshCw } from "lucide-react";

/* ── helpers ─────────────────────────── */
const ACCOUNT_TYPES = [
  {
    key: "personal",
    label: "Personal",
    sub: "Track income, expenses & budgets",
    icon: User,
    color: "border-navy-600 hover:border-orange-500",
    activeColor: "border-orange-500 bg-orange-500/5",
  },
  {
    key: "business",
    label: "Business",
    sub: "Sales, inventory, staff & reports",
    icon: Building2,
    color: "border-navy-600 hover:border-orange-500",
    activeColor: "border-orange-500 bg-orange-500/5",
  },
];

function OTPInput({ value, onChange }) {
  const inputs = useRef([]);

  const handleKey = (e, i) => {
    if (e.key === "Backspace" && !e.target.value && i > 0) {
      inputs.current[i - 1]?.focus();
    }
  };

  const handleChange = (e, i) => {
    const v = e.target.value.replace(/\D/g, "").slice(-1);
    const arr = value.split("");
    arr[i] = v;
    const next = arr.join("").padEnd(6, "").slice(0, 6);
    onChange(next);
    if (v && i < 5) inputs.current[i + 1]?.focus();
  };

  const handlePaste = (e) => {
    const pasted = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
    onChange(pasted.padEnd(6, "").slice(0, 6));
    inputs.current[Math.min(pasted.length, 5)]?.focus();
    e.preventDefault();
  };

  return (
    <div className="flex gap-2 justify-center">
      {Array.from({ length: 6 }).map((_, i) => (
        <input
          key={i}
          ref={(el) => (inputs.current[i] = el)}
          maxLength={1}
          value={value[i] || ""}
          onChange={(e) => handleChange(e, i)}
          onKeyDown={(e) => handleKey(e, i)}
          onPaste={handlePaste}
          inputMode="numeric"
          className="h-13 w-11 rounded-xl border border-navy-700 bg-navy-950 text-center text-xl font-bold text-white outline-none transition focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20"
        />
      ))}
    </div>
  );
}

/* ── main component ───────────────────── */
export default function LoginPage() {
  const { sendOtp, verifyOtp, loading, isLoggedIn, user } = useAuth();
  const navigate = useNavigate();

  const [step, setStep] = useState(1); // 1=type, 2=email, 3=otp
  const [accountType, setAccountType] = useState("");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [remember, setRemember] = useState(false);
  const [resendTimer, setResendTimer] = useState(0);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [devOtp, setDevOtp] = useState(""); // shown in dev mode

  // Already logged in?
  useEffect(() => {
    if (isLoggedIn) {
      navigate(user?.account_type === "personal" ? "/personal/dashboard" : "/dashboard");
    }
  }, [isLoggedIn]);

  // Resend countdown
  useEffect(() => {
    if (resendTimer <= 0) return;
    const t = setInterval(() => setResendTimer((p) => (p > 0 ? p - 1 : 0)), 1000);
    return () => clearInterval(t);
  }, [resendTimer]);

  const clearMessages = () => { setError(""); setInfo(""); };

  /* STEP 2 → send OTP */
  const handleSendOtp = async (e) => {
    e.preventDefault();
    clearMessages();
    if (!email.trim()) { setError("Please enter your email address."); return; }
    const result = await sendOtp(email.trim().toLowerCase(), accountType);
    if (result.ok) {
      setStep(3);
      setResendTimer(60);
      setInfo(`OTP sent to ${email}`);
      if (result.otp) setDevOtp(result.otp); // dev mode
    } else {
      setError(result.error);
    }
  };

  /* STEP 3 → verify OTP */
  const handleVerify = async (e) => {
    e.preventDefault();
    clearMessages();
    if (otp.replace(/\D/g, "").length < 6) { setError("Please enter the complete 6-digit OTP."); return; }
    const result = await verifyOtp(email, otp, accountType, remember);
    if (result.ok) {
      const dest =
        result.accountType === "personal"
          ? "/personal/dashboard"
          : result.isNew
          ? "/create-business"
          : result.businesses?.length > 1
          ? "/select-business"
          : "/dashboard";
      navigate(dest);
    } else {
      setError(result.error);
      setOtp("");
    }
  };

  const handleResend = async () => {
    if (resendTimer > 0) return;
    clearMessages();
    const result = await sendOtp(email, accountType);
    if (result.ok) {
      setResendTimer(60);
      setInfo("New OTP sent.");
      if (result.otp) setDevOtp(result.otp);
    } else {
      setError(result.error);
    }
  };

  /* ── render ─── */
  return (
    <div className="flex min-h-screen items-center justify-center bg-navy-950 px-4 py-10">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="mb-8 flex flex-col items-center gap-3 text-center">
          <img src={bewosyLogo} alt="Bewosy" className="h-16 w-16 rounded-2xl object-cover shadow-lg shadow-orange-500/20" />
          <div>
            <h1 className="text-2xl font-extrabold text-white">Bewosy</h1>
            <p className="text-sm text-navy-400">Smart business management</p>
          </div>
        </div>

        {/* Card */}
        <div className="rounded-3xl border border-navy-800 bg-navy-900/80 p-7 shadow-2xl">
          {/* Progress dots */}
          <div className="mb-6 flex items-center justify-center gap-2">
            {[1, 2, 3].map((s) => (
              <div
                key={s}
                className={`rounded-full transition-all ${
                  s === step ? "h-2.5 w-8 bg-orange-500" : s < step ? "h-2.5 w-2.5 bg-orange-500/60" : "h-2.5 w-2.5 bg-navy-700"
                }`}
              />
            ))}
          </div>

          {/* Error / info */}
          {error && (
            <div className="mb-4 rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-2.5 text-sm text-red-400">
              {error}
            </div>
          )}
          {info && !error && (
            <div className="mb-4 rounded-xl border border-orange-500/30 bg-orange-500/10 px-4 py-2.5 text-sm text-orange-300">
              {info}
            </div>
          )}
          {devOtp && (
            <div className="mb-4 rounded-xl border border-yellow-500/30 bg-yellow-500/10 px-4 py-2.5 text-center text-sm text-yellow-300">
              Dev OTP: <span className="font-bold tracking-widest">{devOtp}</span>
            </div>
          )}

          {/* ── STEP 1: Choose account type ── */}
          {step === 1 && (
            <div>
              <h2 className="mb-1 text-center text-lg font-bold text-white">Welcome</h2>
              <p className="mb-6 text-center text-sm text-navy-400">Choose your account type to get started</p>
              <div className="space-y-3">
                {ACCOUNT_TYPES.map(({ key, label, sub, icon: Icon, color, activeColor }) => (
                  <button
                    key={key}
                    onClick={() => { setAccountType(key); setStep(2); clearMessages(); }}
                    className={`flex w-full items-center gap-4 rounded-2xl border-2 p-4 text-left transition ${
                      accountType === key ? activeColor : color
                    } bg-navy-950/60`}
                  >
                    <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl ${
                      key === "personal" ? "bg-blue-500/15" : "bg-orange-500/15"
                    }`}>
                      <Icon className={`h-6 w-6 ${key === "personal" ? "text-blue-400" : "text-orange-400"}`} />
                    </div>
                    <div>
                      <p className="font-semibold text-white">{label}</p>
                      <p className="text-xs text-navy-400">{sub}</p>
                    </div>
                    <ArrowRight className="ml-auto h-4 w-4 shrink-0 text-navy-500" />
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* ── STEP 2: Enter email ── */}
          {step === 2 && (
            <form onSubmit={handleSendOtp}>
              <div className="mb-1 flex items-center gap-2">
                <button type="button" onClick={() => { setStep(1); clearMessages(); }} className="text-navy-400 hover:text-white">
                  <ArrowLeft className="h-4 w-4" />
                </button>
                <h2 className="text-lg font-bold text-white">Enter your email</h2>
              </div>
              <p className="mb-5 ml-6 text-sm text-navy-400">
                We'll send a verification code to your email.
              </p>

              <div className="mb-2 flex items-center gap-2 rounded-xl border border-navy-700 bg-navy-900/60 px-3 py-1.5">
                {accountType === "personal"
                  ? <User className="h-4 w-4 text-blue-400" />
                  : <Building2 className="h-4 w-4 text-orange-400" />}
                <span className="text-xs font-medium capitalize text-navy-300">{accountType}</span>
              </div>

              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="example@gmail.com"
                autoFocus
                className="w-full rounded-2xl border border-navy-700 bg-navy-950 px-4 py-3.5 text-white outline-none transition placeholder:text-navy-500 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20"
              />

              <button
                type="submit"
                disabled={loading}
                className="mt-4 flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-3.5 font-bold text-white transition hover:bg-orange-400 disabled:opacity-60"
              >
                {loading ? "Sending…" : <>Send OTP <ArrowRight className="h-4 w-4" /></>}
              </button>
            </form>
          )}

          {/* ── STEP 3: OTP + Remember ── */}
          {step === 3 && (
            <form onSubmit={handleVerify}>
              <div className="mb-1 flex items-center gap-2">
                <button type="button" onClick={() => { setStep(2); setOtp(""); clearMessages(); setDevOtp(""); }} className="text-navy-400 hover:text-white">
                  <ArrowLeft className="h-4 w-4" />
                </button>
                <h2 className="text-lg font-bold text-white">Enter OTP</h2>
              </div>
              <p className="mb-6 ml-6 text-sm text-navy-400">
                6-digit code sent to <span className="text-white">{email}</span>
              </p>

              <OTPInput value={otp} onChange={setOtp} />

              {/* Remember device */}
              <label className="mt-5 flex cursor-pointer items-center gap-3 rounded-xl border border-navy-700 bg-navy-950/60 px-4 py-3">
                <div
                  onClick={() => setRemember(!remember)}
                  className={`flex h-5 w-5 shrink-0 items-center justify-center rounded border-2 transition ${
                    remember ? "border-orange-500 bg-orange-500" : "border-navy-600 bg-transparent"
                  }`}
                >
                  {remember && (
                    <svg viewBox="0 0 10 8" className="h-3 w-3 fill-white"><path d="M1 4l3 3 5-6" stroke="white" strokeWidth="1.5" fill="none" strokeLinecap="round"/></svg>
                  )}
                </div>
                <div>
                  <p className="text-sm font-medium text-white">Keep me signed in for 30 days</p>
                  <p className="text-xs text-navy-400">Skip OTP on this device next time</p>
                </div>
              </label>

              <button
                type="submit"
                disabled={loading || otp.replace(/\D/g, "").length < 6}
                className="mt-4 flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-3.5 font-bold text-white transition hover:bg-orange-400 disabled:opacity-60"
              >
                {loading ? "Verifying…" : <>Verify & Sign In <ArrowRight className="h-4 w-4" /></>}
              </button>

              <button
                type="button"
                onClick={handleResend}
                disabled={resendTimer > 0 || loading}
                className="mt-3 flex w-full items-center justify-center gap-1.5 text-sm text-navy-400 transition hover:text-orange-400 disabled:opacity-40"
              >
                <RefreshCw className="h-3.5 w-3.5" />
                {resendTimer > 0 ? `Resend OTP in ${resendTimer}s` : "Resend OTP"}
              </button>
            </form>
          )}
        </div>

        <p className="mt-4 text-center text-xs text-navy-500">
          By continuing you agree to Bewosy's Terms of Service
        </p>
      </div>
    </div>
  );
}
