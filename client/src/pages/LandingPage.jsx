import { useEffect, useState } from "react";
import axios from "axios";
import { useNavigate } from "react-router-dom";

const API = import.meta.env.VITE_API_URL || "http://localhost:5000/api";

export default function Login() {
  const navigate = useNavigate();

  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const [messageType, setMessageType] = useState("info");
  const [resendTimer, setResendTimer] = useState(0);

  const [form, setForm] = useState({
    name: "",
    phone: "",
    code: "",
  });

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (token) {
      navigate("/dashboard");
    }
  }, [navigate]);

  useEffect(() => {
    if (resendTimer <= 0) return;

    const timer = setInterval(() => {
      setResendTimer((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);

    return () => clearInterval(timer);
  }, [resendTimer]);

  const showMessage = (text, type = "info") => {
    setMessage(text);
    setMessageType(type);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleRequestOtp = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMessage("");

    try {
      if (!form.phone.trim()) {
        showMessage("Please enter your mobile number.", "error");
        return;
      }

      const res = await axios.post(
        `${API}/auth/request-otp`,
        {
          phone: form.phone.trim(),
        },
        {
          headers: {
            "Content-Type": "application/json",
          },
          withCredentials: true,
        }
      );

      showMessage(res.data?.message || "OTP sent successfully", "success");
      setStep(2);
      setResendTimer(60);
    } catch (error) {
      console.log("REQUEST OTP ERROR:", error.response?.data || error.message);
      showMessage(
        error?.response?.data?.message || "Failed to send OTP.",
        "error"
      );
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMessage("");

    try {
      if (!form.phone.trim()) {
        showMessage("Please enter your mobile number.", "error");
        return;
      }

      if (!form.code.trim()) {
        showMessage("Please enter OTP code.", "error");
        return;
      }

      const payload = {
        name: String(form.name ?? "").trim() || "Business Owner",
        phone: form.phone.trim(),
        code: form.code.trim(),
      };

      console.log("VERIFY PAYLOAD:", payload);

      const res = await axios.post(`${API}/auth/verify-otp`, payload, {
        headers: {
          "Content-Type": "application/json",
        },
        withCredentials: true,
      });

      const { accessToken, user, message } = res.data;

      localStorage.setItem("token", accessToken);
      localStorage.setItem("user", JSON.stringify(user));

      showMessage(message || "Login successful", "success");

      setTimeout(() => {
        navigate("/dashboard");
      }, 500);
    } catch (error) {
      console.log("VERIFY OTP ERROR:", error.response?.data || error.message);
      showMessage(
        error?.response?.data?.message || "OTP verification failed.",
        "error"
      );
    } finally {
      setLoading(false);
    }
  };

  const handleResendOtp = async () => {
    if (resendTimer > 0) return;

    setLoading(true);
    setMessage("");

    try {
      const res = await axios.post(
        `${API}/auth/request-otp`,
        {
          phone: form.phone.trim(),
        },
        {
          headers: {
            "Content-Type": "application/json",
          },
          withCredentials: true,
        }
      );

      showMessage(res.data?.message || "OTP resent successfully", "success");
      setResendTimer(60);
    } catch (error) {
      console.log("RESEND OTP ERROR:", error.response?.data || error.message);
      showMessage(
        error?.response?.data?.message || "Failed to resend OTP.",
        "error"
      );
    } finally {
      setLoading(false);
    }
  };

  const getMessageClasses = () => {
    if (messageType === "success") {
      return "border-emerald-500/30 bg-emerald-500/10 text-emerald-300";
    }
    if (messageType === "error") {
      return "border-red-500/30 bg-red-500/10 text-red-300";
    }
    return "border-slate-700 bg-slate-800/70 text-slate-300";
  };

  return (
    <div className="min-h-screen bg-slate-950 text-white">
      <div className="grid min-h-screen lg:grid-cols-2">
        <div className="relative hidden overflow-hidden lg:flex">
          <div className="absolute inset-0 bg-gradient-to-br from-emerald-900/20 via-slate-950 to-slate-950" />
          <div className="absolute left-0 top-10 h-72 w-72 rounded-full bg-emerald-500/20 blur-3xl" />
          <div className="absolute bottom-10 right-10 h-80 w-80 rounded-full bg-green-400/10 blur-3xl" />

          <div className="relative z-10 flex w-full flex-col justify-between p-12">
            <div>
              <div className="inline-flex items-center gap-2 rounded-full border border-emerald-500/20 bg-emerald-500/10 px-4 py-2 text-sm text-emerald-300">
                <span className="h-2 w-2 rounded-full bg-emerald-400" />
                Secure OTP Login
              </div>

              <h1 className="mt-8 max-w-xl text-5xl font-bold leading-tight">
                Manage your business with one secure login.
              </h1>

              <p className="mt-5 max-w-lg text-lg leading-8 text-slate-300">
                Parties, items, sales, purchases, payments, expenses, reports,
                recycle bin, and staff access — all connected to your backend.
              </p>

              <div className="mt-10 grid max-w-xl grid-cols-2 gap-4">
                <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
                  <div className="text-2xl font-bold text-emerald-400">OTP</div>
                  <div className="mt-1 text-sm text-slate-300">
                    Login with Nepal mobile number
                  </div>
                </div>

                <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
                  <div className="text-2xl font-bold text-emerald-400">Fast</div>
                  <div className="mt-1 text-sm text-slate-300">
                    Request and verify in 2 steps
                  </div>
                </div>

                <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
                  <div className="text-2xl font-bold text-emerald-400">Safe</div>
                  <div className="mt-1 text-sm text-slate-300">
                    Refresh cookie supported by backend
                  </div>
                </div>

                <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
                  <div className="text-2xl font-bold text-emerald-400">Ready</div>
                  <div className="mt-1 text-sm text-slate-300">
                    Redirect to dashboard after login
                  </div>
                </div>
              </div>
            </div>

            <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-6">
              <p className="text-sm uppercase tracking-[0.2em] text-slate-400">
                Connected Backend Modules
              </p>
              <div className="mt-4 flex flex-wrap gap-3">
                {[
                  "Dashboard",
                  "Parties",
                  "Items",
                  "Sales",
                  "Purchases",
                  "Payments",
                  "Expenses",
                  "Reports",
                ].map((item) => (
                  <span
                    key={item}
                    className="rounded-full border border-emerald-500/20 bg-emerald-500/10 px-3 py-1.5 text-sm text-emerald-200"
                  >
                    {item}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>

        <div className="flex items-center justify-center px-5 py-10 sm:px-8 lg:px-12">
          <div className="w-full max-w-md">
            <div className="mb-8">
              <h2 className="text-3xl font-bold tracking-tight">Bepar Login</h2>
              <p className="mt-2 text-sm text-slate-400">
                Sign in using OTP verification
              </p>
            </div>

            <div className="rounded-3xl border border-slate-800 bg-slate-900/90 p-6 shadow-2xl shadow-black/30 sm:p-8">
              <div className="mb-6 flex items-center gap-3">
                <div
                  className={`flex h-9 w-9 items-center justify-center rounded-full text-sm font-bold ${
                    step >= 1
                      ? "bg-emerald-500 text-slate-950"
                      : "bg-slate-800 text-slate-400"
                  }`}
                >
                  1
                </div>
                <div className="h-px flex-1 bg-slate-800" />
                <div
                  className={`flex h-9 w-9 items-center justify-center rounded-full text-sm font-bold ${
                    step >= 2
                      ? "bg-emerald-500 text-slate-950"
                      : "bg-slate-800 text-slate-400"
                  }`}
                >
                  2
                </div>
              </div>

              {message && (
                <div
                  className={`mb-5 rounded-2xl border px-4 py-3 text-sm ${getMessageClasses()}`}
                >
                  {message}
                </div>
              )}

              {step === 1 ? (
                <form onSubmit={handleRequestOtp} className="space-y-5">
                  <div>
                    <label className="mb-2 block text-sm font-medium text-slate-300">
                      Name
                    </label>
                    <input
                      type="text"
                      name="name"
                      value={form.name}
                      onChange={handleChange}
                      placeholder="Enter your name"
                      className="w-full rounded-2xl border border-slate-700 bg-slate-950 px-4 py-3 text-white outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
                    />
                  </div>

                  <div>
                    <label className="mb-2 block text-sm font-medium text-slate-300">
                      Mobile Number
                    </label>
                    <input
                      type="text"
                      name="phone"
                      value={form.phone}
                      onChange={handleChange}
                      placeholder="98XXXXXXXX"
                      className="w-full rounded-2xl border border-slate-700 bg-slate-950 px-4 py-3 text-white outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full rounded-2xl bg-emerald-500 px-4 py-3.5 font-semibold text-slate-950 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-70"
                  >
                    {loading ? "Sending OTP..." : "Send OTP"}
                  </button>
                </form>
              ) : (
              <form onSubmit={handleVerifyOtp} className="space-y-5">
  <div>
    <label className="mb-2 block text-sm font-medium text-slate-300">
      Name
    </label>
    <input
      type="text"
      name="name"
      value={form.name}
      onChange={handleChange}
      placeholder="Enter your name"
      className="w-full rounded-2xl border border-slate-700 bg-slate-950 px-4 py-3 text-white outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
    />
  </div>

  <div>
    <label className="mb-2 block text-sm font-medium text-slate-300">
      Mobile Number
    </label>
    <input
      type="text"
      name="phone"
      value={form.phone}
      onChange={handleChange}
      className="w-full rounded-2xl border border-slate-700 bg-slate-950 px-4 py-3 text-white outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
    />
  </div>

  <div>
    <label className="mb-2 block text-sm font-medium text-slate-300">
      OTP Code
    </label>
    <input
      type="text"
      name="code"
      value={form.code}
      onChange={handleChange}
      placeholder="Enter OTP"
      maxLength={6}
      className="w-full rounded-2xl border border-slate-700 bg-slate-950 px-4 py-3 text-center text-xl tracking-[0.35em] text-white outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
    />
  </div>

  <button
    type="submit"
    disabled={loading}
    className="w-full rounded-2xl bg-emerald-500 px-4 py-3.5 font-semibold text-slate-950 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-70"
  >
    {loading ? "Verifying..." : "Verify & Login"}
  </button>

  <div className="flex flex-col gap-3 sm:flex-row">
    <button
      type="button"
      onClick={() => setStep(1)}
      className="flex-1 rounded-2xl border border-slate-700 px-4 py-3 text-slate-200 transition hover:bg-slate-800"
    >
      Change Number
    </button>

    <button
      type="button"
      onClick={handleResendOtp}
      disabled={resendTimer > 0 || loading}
      className="flex-1 rounded-2xl border border-emerald-500/30 px-4 py-3 text-emerald-300 transition hover:bg-emerald-500/10 disabled:cursor-not-allowed disabled:opacity-50"
    >
      {resendTimer > 0 ? `Resend in ${resendTimer}s` : "Resend OTP"}
    </button>
  </div>
</form>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}