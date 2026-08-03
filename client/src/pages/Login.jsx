import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import bewosyLogo from "../assessts/images/bewosy.jpeg";
import { Mail, ArrowRight, TrendingUp, Package, Users, BarChart3, Check } from "lucide-react";
import { Steps } from "../components/auth/AuthWidgets";

/* ─── Login page — email entry (sign-in, or step 2 of the signup flow) ─── */
export default function LoginPage() {
  const { sendOtp, loading, isLoggedIn, user } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const isSignup = location.state?.isSignup ?? false;
  const accountType = location.state?.accountType;

  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");

  useEffect(() => {
    if (isLoggedIn) {
      navigate(user?.account_type === "personal" ? "/personal/dashboard" : "/dashboard", { replace: true });
    }
  }, [isLoggedIn]);

  const handleSendOtp = async (e) => {
    e?.preventDefault();
    setError(""); setInfo("");
    const trimmed = email.trim().toLowerCase();
    if (!trimmed || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
      setError("Please enter a valid email address.");
      return;
    }
    const res = await sendOtp(trimmed, isSignup);
    if (res.ok) {
      navigate("/verify-otp", { state: { email: trimmed, userExists: res.userExists, accountType } });
    } else {
      setError(res.error);
      // If the email already exists and they tried to sign up, hint to switch mode
      if (res.userExists) {
        setInfo("This email is already registered — try signing in instead.");
      }
    }
  };

  return (
    <div className="flex min-h-screen flex-col bg-navy-950">
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

            <Steps
              current={isSignup ? 2 : 1}
              steps={isSignup ? ["Profile", "Email", "Verify"] : ["Email", "Verify"]}
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

            <form onSubmit={handleSendOtp}>
              <div className="mb-5 text-center">
                <h2 className="text-xl font-bold text-white">
                  {isSignup ? "Create your account" : "Welcome back!"}
                </h2>
                <p className="mt-1.5 text-sm text-navy-400">
                  {isSignup
                    ? "Enter your Gmail or email to get started"
                    : "Enter your email to receive a sign-in code"}
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

              {!isSignup && (
                <button
                  type="button"
                  onClick={() => navigate("/choose-profile")}
                  className="mt-5 block w-full text-center text-sm font-semibold text-orange-400 hover:text-orange-300 transition"
                >
                  New to Bewosy? Get Started
                </button>
              )}
            </form>
          </div>

          <p className="mt-5 text-center text-xs text-navy-500">
            By continuing you agree to Bewosy's Terms of Service
          </p>
        </div>
      </div>
    </div>
  );
}
