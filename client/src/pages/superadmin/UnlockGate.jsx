import { useState } from "react";
import { ShieldCheck, Loader, Mail } from "lucide-react";
import { superadmin as adminApi } from "../../api";

// Shown instead of the Super Admin panel until it's unlocked: type the Super
// Admin email, receive a code there, enter it. Being signed in isn't enough —
// the server refuses Super Admin data without a recent unlock too.
export default function UnlockGate({ onUnlocked }) {
  const [step, setStep] = useState("email"); // "email" | "code"
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");

  const send = async (e) => {
    e?.preventDefault();
    if (!email.trim()) return;
    setBusy(true); setError(""); setInfo("");
    try {
      const { data } = await adminApi.unlockSend(email.trim());
      setInfo(data.message || "Code sent.");
      setStep("code");
    } catch (err) {
      setError(err.response?.data?.message || "Couldn't send the code. Please try again.");
    } finally { setBusy(false); }
  };

  const verify = async (e) => {
    e.preventDefault();
    if (!code.trim()) return;
    setBusy(true); setError("");
    try {
      await adminApi.unlockVerify(code.trim());
      onUnlocked();
    } catch (err) {
      setError(err.response?.data?.message || "Incorrect code. Please try again.");
    } finally { setBusy(false); }
  };

  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-4 py-3 text-white placeholder:text-navy-600 focus:border-orange-500 focus:outline-none";

  return (
    <div className="flex min-h-[60vh] items-center justify-center px-4">
      <div className="w-full max-w-sm rounded-3xl border border-navy-800 bg-navy-900/80 px-6 py-7 shadow-2xl">
        <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-orange-500/15">
          <ShieldCheck className="h-7 w-7 text-orange-400" />
        </div>
        <h2 className="text-center text-xl font-bold text-white">Verify to open Super Admin</h2>
        <p className="mt-2 mb-5 text-center text-sm text-navy-400">
          {step === "email"
            ? "Enter the Super Admin email. We'll send a code to it."
            : `Enter the code sent to ${email}.`}
        </p>

        {step === "email" ? (
          <form onSubmit={send} className="space-y-3">
            <input type="email" autoFocus value={email} onChange={e => { setEmail(e.target.value); setError(""); }}
              placeholder="Super Admin email" className={field} />
            <button type="submit" disabled={busy || !email.trim()}
              className="flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-3 font-bold text-white hover:bg-orange-400 disabled:opacity-60">
              {busy ? <Loader className="h-4 w-4 animate-spin" /> : <Mail className="h-4 w-4" />} Send code
            </button>
          </form>
        ) : (
          <form onSubmit={verify} className="space-y-3">
            <input inputMode="numeric" autoFocus value={code} maxLength={6}
              onChange={e => { setCode(e.target.value.replace(/\D/g, "")); setError(""); }}
              placeholder="6-digit code" className={`${field} text-center text-2xl font-bold tracking-[0.4em]`} />
            <button type="submit" disabled={busy || code.length < 4}
              className="flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-3 font-bold text-white hover:bg-orange-400 disabled:opacity-60">
              {busy && <Loader className="h-4 w-4 animate-spin" />} Verify & open
            </button>
            <button type="button" onClick={send} disabled={busy}
              className="w-full text-center text-xs text-navy-400 hover:text-navy-200">
              Didn't get it? Send again
            </button>
          </form>
        )}

        {info && !error && <p className="mt-3 text-center text-xs text-green-400">{info}</p>}
        {error && <p className="mt-3 rounded-xl bg-red-500/10 px-3 py-2 text-center text-sm text-red-400">{error}</p>}
      </div>
    </div>
  );
}
