import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { auth as authApi } from "../api/index.js";

/* Public page at /delete-account — the account-deletion link Google Play asks
   for. Signed out, it explains what is deleted and how; signed in, it deletes
   the account after a fresh code emailed to it (same as the app's Settings). */
export default function DeleteAccountPage() {
  const { user, isLoggedIn, logout } = useAuth();
  const navigate = useNavigate();
  const [codeSent, setCodeSent] = useState(false);
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [done, setDone] = useState(false);

  const message = (err, fallback) => err.response?.data?.message || err.response?.data?.detail || fallback;

  const sendCode = async () => {
    setBusy(true); setError("");
    try {
      await authApi.sendOtp(user.email);
      setCodeSent(true);
    } catch (err) {
      setError(message(err, "Couldn't send the code. Please try again."));
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    if (!code.trim()) { setError("Enter the code we emailed you."); return; }
    if (!window.confirm("Delete your account and all data of the businesses you own? This cannot be undone.")) return;
    setBusy(true); setError("");
    try {
      await authApi.deleteAccount(code.trim());
      setDone(true);
      await logout();
    } catch (err) {
      setError(message(err, "Couldn't delete the account. Please try again."));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen bg-navy-950 px-4 py-12 text-navy-100">
      <div className="mx-auto max-w-xl space-y-6">
        <Link to="/" className="text-sm text-orange-400 hover:underline">← Bewosai</Link>
        <h1 className="text-2xl font-bold text-white">Delete your Bewosai account</h1>

        <div className="rounded-xl border border-navy-800 bg-navy-900 p-5 text-sm space-y-2">
          <p className="font-semibold text-white">What gets deleted</p>
          <ul className="list-disc pl-5 space-y-1">
            <li>Your account and sign-in</li>
            <li>Every business you own, with all its sales, purchases, stock, parties, payments, expenses and bank records</li>
            <li>Your staff access to businesses owned by others (their data stays with them)</li>
          </ul>
          <p className="text-red-400 font-semibold">Deletion is immediate and permanent. Download any reports you need first.</p>
          <p className="text-navy-400">You can also do this in the app: Settings → Delete Account.</p>
        </div>

        {done ? (
          <div className="rounded-xl border border-green-500/40 bg-green-500/10 p-5 text-sm text-green-300">
            Your account and its data have been deleted.
            <button onClick={() => navigate("/")} className="ml-2 underline">Go to home</button>
          </div>
        ) : !isLoggedIn ? (
          <div className="rounded-xl border border-navy-800 bg-navy-900 p-5 text-sm">
            <p className="mb-3">Sign in with the account you want to delete, then come back to this page.</p>
            <Link to="/login" className="inline-block rounded-lg bg-orange-500 px-4 py-2 font-semibold text-white">Sign in</Link>
          </div>
        ) : (
          <div className="rounded-xl border border-navy-800 bg-navy-900 p-5 text-sm space-y-3">
            <p>Signed in as <span className="font-semibold text-white">{user?.email}</span></p>
            {!codeSent ? (
              <button onClick={sendCode} disabled={busy}
                className="rounded-lg bg-orange-500 px-4 py-2 font-semibold text-white disabled:opacity-60">
                {busy ? "Sending…" : "Email me a confirmation code"}
              </button>
            ) : (
              <>
                <input value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" maxLength={6}
                  placeholder="6-digit code"
                  className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-white focus:border-orange-500 focus:outline-none" />
                <div className="flex flex-wrap gap-2">
                  <button onClick={remove} disabled={busy}
                    className="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white disabled:opacity-60">
                    {busy ? "Deleting…" : "Delete my account"}
                  </button>
                  <button onClick={sendCode} disabled={busy} className="rounded-lg px-4 py-2 text-navy-300 hover:text-white">
                    Send a new code
                  </button>
                </div>
              </>
            )}
            {error && <p className="text-red-400">{error}</p>}
          </div>
        )}
      </div>
    </div>
  );
}
