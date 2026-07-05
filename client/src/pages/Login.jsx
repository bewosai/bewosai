import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import bewosyLogo from "../assessts/images/bewosy.jpeg";
import {
  User, Building2, ArrowRight, ArrowLeft, RefreshCw,
  Check, Mail, Smartphone, TrendingUp, Package, Users, BarChart3,
} from "lucide-react";

/* ─── OTP 6-box input ─────────────────────── */
function OTPInput({ value, onChange, disabled }) {
  const inputs = useRef([]);

  const handleChange = (e, i) => {
    const v = e.target.value.replace(/\D/g, "").slice(-1);
    const arr = (value + "      ").slice(0, 6).split("");
    arr[i] = v;
    onChange(arr.join("").trimEnd().slice(0, 6));
    if (v && i < 5) inputs.current[i + 1]?.focus();
  };

  const handleKey = (e, i) => {
    if (e.key === "Backspace" && !e.target.value && i > 0) {
      inputs.current[i - 1]?.focus();
    }
  };

  const handlePaste = (e) => {
    const p = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
    onChange(p.padEnd(6, " ").slice(0, 6).trimEnd());
    inputs.current[Math.min(p.length, 5)]?.focus();
    e.preventDefault();
  };

  return (
    <div className="flex justify-center gap-2">
      {Array.from({ length: 6 }).map((_, i) => (
        <input
          key={i}
          id={`otp-${i}`}
          name={`otp-${i}`}
          ref={(el) => (inputs.current[i] = el)}
          maxLength={1}
          value={(value || "")[i] || ""}
          onChange={(e) => handleChange(e, i)}
          onKeyDown={(e) => handleKey(e, i)}
          onPaste={handlePaste}
          inputMode="numeric"
          autoComplete="one-time-code"
          disabled={disabled}
          className={`h-14 w-11 rounded-2xl border-2 bg-navy-950 text-center text-xl font-bold text-white outline-none transition focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 disabled:opacity-50 ${
            (value || "")[i] ? "border-orange-500" : "border-navy-700"
          }`}
        />
      ))}
    </div>
  );
}

/* ─── Profile card ──────────────────────── */
function ProfileCard({ type, label, description, features, icon: Icon, iconColor, selected, onSelect }) {
  return (
    <button
      onClick={onSelect}
      className={`relative w-full rounded-2xl border-2 p-5 text-left transition-all duration-200 ${
        selected
          ? "border-orange-500 bg-orange-500/8 shadow-lg shadow-orange-500/10"
          : "border-navy-700 bg-navy-950/60 hover:border-navy-500"
      }`}
    >
      {selected && (
        <div className="absolute right-3 top-3 flex h-6 w-6 items-center justify-center rounded-full bg-orange-500">
          <Check className="h-3.5 w-3.5 text-white" />
        </div>
      )}
      <div className={`mb-3 flex h-12 w-12 items-center justify-center rounded-xl ${iconColor}`}>
        <Icon className="h-6 w-6" />
      </div>
      <p className="text-base font-bold text-white">{label}</p>
      <p className="mt-1 text-xs text-navy-400">{description}</p>
      <div className="mt-3 flex flex-wrap gap-1.5">
        {features.map((f) => (
          <span key={f} className="rounded-full bg-navy-800 px-2.5 py-1 text-[10px] text-navy-400">{f}</span>
        ))}
      </div>
    </button>
  );
}

/* ─── Step indicators ─── */
function Steps({ current, isNew }) {
  const steps = isNew ? ["Email", "Verify", "Profile"] : ["Email", "Verify"];
  return (
    <div className="mb-6 flex items-center justify-center gap-2">
      {steps.map((label, i) => {
        const n = i + 1;
        const done = n < current;
        const active = n === current;
        return (
          <div key={label} className="flex items-center gap-2">
            <div className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold transition ${
              done ? "bg-green-500 text-white" : active ? "bg-orange-500 text-white" : "bg-navy-800 text-navy-500"
            }`}>
              {done ? <Check className="h-3.5 w-3.5" /> : n}
            </div>
            <span className={`text-xs ${active ? "text-white font-medium" : "text-navy-500"}`}>{label}</span>
            {i < steps.length - 1 && <div className={`h-px w-6 ${done ? "bg-green-500" : "bg-navy-700"}`} />}
          </div>
        );
      })}
    </div>
  );
}

/* ─── Main Login page ─────────────────────── */
export default function LoginPage() {
  const { sendOtp, verifyOtp, setAccountType, loading, isLoggedIn, user } = useAuth();
  const navigate = useNavigate();

  // Steps: 1=email, 2=otp, 3=profile (new users only)
  const [mode, setMode] = useState("signin"); // "signin" | "signup"
  const [step, setStep] = useState(1);
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [remember, setRemember] = useState(false);
  const [resendTimer, setResendTimer] = useState(0);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [devOtp, setDevOtp] = useState("");
  const [userExists, setUserExists] = useState(false);
  const [isNewUser, setIsNewUser] = useState(false);
  const [selectedProfile, setSelectedProfile] = useState("");

  useEffect(() => {
    if (isLoggedIn) {
      navigate(user?.account_type === "personal" ? "/personal/dashboard" : "/dashboard", { replace: true });
    }
  }, [isLoggedIn]);

  useEffect(() => {
    if (resendTimer <= 0) return;
    const t = setInterval(() => setResendTimer((p) => Math.max(0, p - 1)), 1000);
    return () => clearInterval(t);
  }, [resendTimer]);

  const clear = () => { setError(""); setInfo(""); };

  const switchMode = (m) => { setMode(m); setError(""); setInfo(""); setEmail(""); };

  /* ── Step 1 → Send OTP ── */
  const handleSendOtp = async (e) => {
    e?.preventDefault();
    clear();
    const trimmed = email.trim().toLowerCase();
    if (!trimmed || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
      setError("Please enter a valid email address.");
      return;
    }
    const isSignup = mode === "signup";
    const res = await sendOtp(trimmed, isSignup);
    if (res.ok) {
      setEmail(trimmed);
      setUserExists(res.userExists);
      setStep(2);
      setResendTimer(60);
      setInfo(res.userExists ? `Welcome back! OTP sent to ${trimmed}` : `New account — OTP sent to ${trimmed}`);
      if (res.otp) setDevOtp(res.otp);
    } else {
      setError(res.error);
      // If the email already exists and they tried to sign up, hint to switch mode
      if (res.userExists) {
        setInfo("Tip: Switch to Sign In to access your existing account.");
      }
    }
  };

  /* ── Step 2 → Verify OTP ── */
  const handleVerify = async (e) => {
    e?.preventDefault();
    clear();
    const digits = otp.replace(/\s/g, "");
    if (digits.length < 6) { setError("Enter the complete 6-digit OTP."); return; }
    const res = await verifyOtp(email, digits, remember);
    if (res.ok) {
      if (res.needsProfileSetup) {
        // New user — must pick profile
        setIsNewUser(true);
        setStep(3);
      } else {
        // Existing user → go directly to their dashboard
        const dest = res.accountType === "personal"
          ? "/personal/dashboard"
          : res.businesses?.length > 1 ? "/select-business" : "/dashboard";
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
    const res = await sendOtp(email);
    if (res.ok) {
      setResendTimer(60);
      setInfo("New OTP sent.");
      if (res.otp) setDevOtp(res.otp);
    } else {
      setError(res.error);
    }
  };

  /* ── render ── */
  return (
    <div className="flex min-h-screen flex-col bg-navy-950">
      {/* Top area with gradient */}
      <div className="flex flex-1 flex-col items-center justify-center px-4 py-8 sm:py-12">
        <div className="w-full max-w-sm">

          {/* Logo */}
          <div className="mb-8 flex flex-col items-center gap-3 text-center">
            <div className="relative">
              <img
                src={bewosyLogo}
                alt="Bewosy"
                className="h-18 w-18 rounded-3xl object-cover shadow-xl shadow-orange-500/20 ring-2 ring-orange-500/30"
                style={{ height: 72, width: 72 }}
              />
              <div className="absolute -bottom-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full bg-orange-500 shadow-md">
                <Check className="h-3.5 w-3.5 text-white" />
              </div>
            </div>
            <div>
              <h1 className="text-2xl font-extrabold text-white">Bewosy</h1>
              <p className="text-xs text-navy-400 mt-0.5">Smart Business Suite</p>
            </div>
          </div>

          {/* Card */}
          <div className="rounded-3xl border border-navy-800 bg-navy-900/80 px-6 py-7 shadow-2xl backdrop-blur-sm">

            <Steps current={step} isNew={isNewUser} />

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
            {devOtp && (
              <div className="mb-4 rounded-xl border border-yellow-500/30 bg-yellow-500/10 px-4 py-2 text-center text-sm text-yellow-300">
                Dev OTP: <span className="font-mono font-bold tracking-[0.3em]">{devOtp}</span>
              </div>
            )}

            {/* ── Step 1: Email ── */}
            {step === 1 && (
              <form onSubmit={handleSendOtp}>
                {/* Sign In / Sign Up toggle */}
                <div className="mb-5 flex rounded-xl bg-navy-950 border border-navy-800 p-1">
                  <button
                    type="button"
                    onClick={() => switchMode("signin")}
                    className={`flex-1 rounded-lg py-2 text-sm font-semibold transition ${mode === "signin" ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}
                  >
                    Sign In
                  </button>
                  <button
                    type="button"
                    onClick={() => switchMode("signup")}
                    className={`flex-1 rounded-lg py-2 text-sm font-semibold transition ${mode === "signup" ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}
                  >
                    Sign Up
                  </button>
                </div>

                <div className="mb-5 text-center">
                  <h2 className="text-xl font-bold text-white">
                    {mode === "signin" ? "Welcome back!" : "Create your account"}
                  </h2>
                  <p className="mt-1.5 text-sm text-navy-400">
                    {mode === "signin"
                      ? "Enter your email to receive a sign-in code"
                      : "Enter your Gmail or email to get started"}
                  </p>
                </div>

                <div className="relative mb-4">
                  <Mail className="absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-navy-500" />
                  <input
                    id="email"
                    name="email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="your@email.com"
                    autoFocus
                    autoComplete="email"
                    inputMode="email"
                    className="w-full rounded-2xl border border-navy-700 bg-navy-950 py-4 pl-11 pr-4 text-base text-white outline-none transition placeholder:text-navy-500 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20"
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-4 text-base font-bold text-white transition hover:bg-orange-400 active:bg-orange-600 disabled:opacity-60"
                >
                  {loading ? (
                    <span className="animate-pulse">Sending…</span>
                  ) : (
                    <>Send OTP <ArrowRight className="h-4 w-4" /></>
                  )}
                </button>

                {/* Feature pills */}
                <div className="mt-5 flex flex-wrap justify-center gap-2">
                  {[
                    { icon: TrendingUp, text: "Sales" },
                    { icon: Package, text: "Inventory" },
                    { icon: Users, text: "Staff" },
                    { icon: BarChart3, text: "Reports" },
                  ].map(({ icon: Icon, text }) => (
                    <span key={text} className="flex items-center gap-1.5 rounded-full bg-navy-800 px-3 py-1.5 text-xs text-navy-400">
                      <Icon className="h-3 w-3 text-orange-400" />{text}
                    </span>
                  ))}
                </div>
              </form>
            )}

            {/* ── Step 2: OTP ── */}
            {step === 2 && (
              <form onSubmit={handleVerify}>
                <button
                  type="button"
                  onClick={() => { setStep(1); setOtp(""); setDevOtp(""); clear(); }}
                  className="mb-4 flex items-center gap-1.5 text-sm text-navy-400 hover:text-white transition"
                >
                  <ArrowLeft className="h-4 w-4" /> Back
                </button>

                <div className="mb-5 text-center">
                  <h2 className="text-xl font-bold text-white">Check your email</h2>
                  <p className="mt-1.5 text-sm text-navy-400">
                    We sent a 6-digit code to<br />
                    <span className="font-semibold text-white">{email}</span>
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
                    type="business"
                    label="Business"
                    description="Complete business management for shops, companies & teams"
                    features={["Sales & Invoices", "Inventory", "Staff & Roles", "Reports", "Purchases"]}
                    icon={Building2}
                    iconColor="bg-orange-500/15 text-orange-500"
                    selected={selectedProfile === "business"}
                    onSelect={() => setSelectedProfile("business")}
                  />
                  <ProfileCard
                    type="personal"
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
            By continuing you agree to Bewosy's Terms of Service
          </p>
        </div>
      </div>
    </div>
  );
}
