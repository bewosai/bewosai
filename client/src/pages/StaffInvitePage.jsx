import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Check, X, Mail, ShieldCheck, Building2 } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import { auth as authApi } from "../api";
import { MODULES, MODULE_LABELS } from "../utils/staffRoles";
import bewosaiLogo from "../assessts/images/bewosai.png";

/* ─── Staff invitation — opened from the link the business admin shared.
     Shows who invited them and exactly what they'll get, then: email → the
     code we email them → Accept (or Decline). Nothing is granted until they
     accept with a correct code. ─── */

const ACTION_WORDS = { view: "view", create: "add", edit: "edit", delete: "delete" };

function accessSummary(row) {
  const can = ["view", "create", "edit", "delete"].filter((a) => row[a]).map((a) => ACTION_WORDS[a]);
  if (can.length === 4) return "Full access";
  if (can.length === 1 && can[0] === "view") return "View only";
  return can.map((w, i) => (i === 0 ? w[0].toUpperCase() + w.slice(1) : w)).join(", ");
}

export default function StaffInvitePage() {
  const { token } = useParams();
  const navigate = useNavigate();
  const { acceptStaffInvite } = useAuth();

  const [invite, setInvite] = useState(null);
  const [problem, setProblem] = useState("");
  const [step, setStep] = useState("email"); // email | code | declined
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");

  useEffect(() => {
    authApi.staffInvite(token)
      .then(({ data }) => setInvite(data))
      .catch((err) => setProblem(err.response?.data?.message || "Couldn't open this invitation. Check your internet and try again."));
  }, [token]);

  const sendCode = async (e) => {
    e?.preventDefault();
    const clean = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clean)) { setError("Enter a valid email address."); return; }
    setBusy(true); setError(""); setInfo("");
    try {
      const { data } = await authApi.sendInviteOtp(clean);
      setEmail(clean);
      setStep("code");
      setInfo(data.message || `We sent a 6-digit code to ${clean}.`);
    } catch (err) {
      setError(err.response?.data?.message || "Couldn't send the code. Please try again.");
    } finally { setBusy(false); }
  };

  const accept = async (e) => {
    e.preventDefault();
    if (!/^\d{6}$/.test(code.trim())) { setError("Enter the 6-digit code from your email."); return; }
    setBusy(true); setError("");
    const res = await acceptStaffInvite(token, email, code.trim());
    setBusy(false);
    if (res.ok) navigate("/dashboard", { replace: true });
    else setError(res.error);
  };

  const decline = async () => {
    if (!window.confirm("Decline this invitation? The link will stop working.")) return;
    setBusy(true); setError("");
    try {
      await authApi.declineStaffInvite(token);
      setStep("declined");
    } catch (err) {
      setError(err.response?.data?.message || "Couldn't decline. Please try again.");
    } finally { setBusy(false); }
  };

  const field = "w-full rounded-xl border border-navy-700 bg-navy-950 px-4 py-3 text-base text-white outline-none placeholder:text-navy-500 focus:border-orange-500";
  const primary = "flex w-full items-center justify-center gap-2 rounded-xl bg-orange-500 px-4 py-3 text-base font-semibold text-white transition hover:bg-orange-400 disabled:opacity-60";

  const shell = (children) => (
    <div className="min-h-screen bg-navy-950 px-4 py-8 text-white">
      <div className="mx-auto w-full max-w-md">
        <div className="mb-6 flex items-center justify-center gap-3">
          <img src={bewosaiLogo} alt="" className="h-11 w-11 rounded-xl object-cover ring-2 ring-orange-500/30" />
          <span className="text-xl font-bold">Bewosai</span>
        </div>
        <div className="rounded-2xl border border-navy-800 bg-navy-900 p-5 sm:p-6">{children}</div>
      </div>
    </div>
  );

  if (problem) {
    return shell(
      <div className="text-center">
        <p className="mb-2 text-lg font-bold">Can't use this invitation</p>
        <p className="text-sm leading-relaxed text-navy-300">{problem}</p>
        <button onClick={() => navigate("/login")} className={`${primary} mt-5`}>Go to sign in</button>
      </div>,
    );
  }
  if (!invite) return shell(<p className="py-6 text-center text-sm text-navy-300 animate-pulse">Opening invitation…</p>);
  if (step === "declined") {
    return shell(
      <div className="text-center">
        <p className="mb-2 text-lg font-bold">Invitation declined</p>
        <p className="text-sm text-navy-300">You haven't joined {invite.business_name}. You can close this page.</p>
      </div>,
    );
  }

  const allowed = MODULES.filter((m) => invite.access[m]?.view);
  const notAllowed = MODULES.filter((m) => !invite.access[m]?.view);

  return shell(
    <>
      <p className="text-sm text-navy-300">You've been invited to join</p>
      <div className="mt-1 flex items-center gap-2">
        <Building2 className="h-5 w-5 shrink-0 text-orange-400" />
        <h1 className="text-xl font-bold leading-tight">{invite.business_name}</h1>
      </div>
      <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
        <div className="rounded-xl bg-navy-950 px-3 py-2.5">
          <dt className="text-xs text-navy-400">Role</dt>
          <dd className="font-semibold">{invite.role_label}</dd>
        </div>
        <div className="rounded-xl bg-navy-950 px-3 py-2.5">
          <dt className="text-xs text-navy-400">Invited by</dt>
          <dd className="truncate font-semibold">{invite.invited_by}</dd>
        </div>
      </dl>

      <div className="mt-4">
        <p className="mb-2 text-sm font-semibold">Access includes</p>
        {allowed.length ? (
          <ul className="space-y-1.5">
            {allowed.map((m) => (
              <li key={m} className="flex items-start gap-2 text-sm">
                <Check className="mt-0.5 h-4 w-4 shrink-0 text-green-400" />
                <span><span className="font-medium">{MODULE_LABELS[m]}</span> <span className="text-navy-400">— {accessSummary(invite.access[m])}</span></span>
              </li>
            ))}
          </ul>
        ) : <p className="text-sm text-navy-400">No sections yet — the admin can add them later.</p>}
        {notAllowed.length > 0 && (
          <>
            <p className="mb-2 mt-4 text-sm font-semibold">Does not include</p>
            <ul className="space-y-1.5">
              {notAllowed.map((m) => (
                <li key={m} className="flex items-center gap-2 text-sm text-navy-300">
                  <X className="h-4 w-4 shrink-0 text-red-400" /> {MODULE_LABELS[m]}
                </li>
              ))}
            </ul>
          </>
        )}
      </div>

      <div className="mt-6 border-t border-navy-800 pt-5">
        {error && <p role="alert" className="mb-3 rounded-xl bg-red-500/10 px-3 py-2.5 text-sm text-red-300">{error}</p>}

        {step === "email" ? (
          <form onSubmit={sendCode} className="space-y-3">
            <label htmlFor="invite-email" className="block text-sm font-semibold">Your email</label>
            {invite.email_hint && <p className="text-xs text-navy-400">This invitation is for {invite.email_hint}</p>}
            <input
              id="invite-email" type="email" inputMode="email" autoComplete="email" autoFocus
              value={email} onChange={(e) => setEmail(e.target.value)}
              placeholder="you@gmail.com" className={field}
            />
            <button type="submit" disabled={busy} className={primary}>
              <Mail className="h-5 w-5" /> {busy ? "Sending code…" : "Send verification code"}
            </button>
          </form>
        ) : (
          <form onSubmit={accept} className="space-y-3">
            {info && <p className="rounded-xl bg-green-500/10 px-3 py-2.5 text-sm text-green-300">{info}</p>}
            <label htmlFor="invite-code" className="block text-sm font-semibold">6-digit code</label>
            <input
              id="invite-code" inputMode="numeric" autoComplete="one-time-code" maxLength={6} autoFocus
              value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              placeholder="123456" className={`${field} text-center text-2xl tracking-[0.4em]`}
            />
            <button type="submit" disabled={busy} className={primary}>
              <ShieldCheck className="h-5 w-5" /> {busy ? "Accepting…" : "Verify & accept invitation"}
            </button>
            <div className="flex flex-wrap justify-between gap-2 text-sm">
              <button type="button" onClick={() => { setStep("email"); setCode(""); setError(""); setInfo(""); }}
                className="py-2 text-navy-300 underline-offset-2 hover:text-white hover:underline">
                Change email
              </button>
              <button type="button" onClick={sendCode} disabled={busy}
                className="py-2 text-orange-400 underline-offset-2 hover:underline disabled:opacity-60">
                Send a new code
              </button>
            </div>
          </form>
        )}

        <button type="button" onClick={decline} disabled={busy}
          className="mt-4 w-full rounded-xl border border-navy-700 px-4 py-3 text-sm font-medium text-navy-200 transition hover:border-red-500/50 hover:text-red-300 disabled:opacity-60">
          Decline invitation
        </button>
        <p className="mt-4 text-center text-xs leading-relaxed text-navy-400">
          You'll only join after you enter the code. The link works once and expires on{" "}
          {new Date(invite.expires_at).toLocaleDateString()}.
        </p>
      </div>
    </>,
  );
}
