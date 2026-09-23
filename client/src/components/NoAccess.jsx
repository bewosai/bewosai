import { useNavigate } from "react-router-dom";
import { Lock } from "lucide-react";

/* Shown in place of a page the signed-in staff member wasn't given access to
   (e.g. by typing its address) — the menu already hides these. */
export default function NoAccess() {
  const navigate = useNavigate();
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center px-4 text-center">
      <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-orange-500/10">
        <Lock className="h-7 w-7 text-orange-400" />
      </div>
      <h1 className="text-lg font-bold text-white">You don't have access to this</h1>
      <p className="mt-1.5 max-w-sm text-sm text-navy-400">
        The business owner hasn't turned this on for your account. Ask them to enable it if you need it.
      </p>
      <button
        onClick={() => navigate("/dashboard")}
        className="mt-5 rounded-xl bg-orange-500 px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-orange-400"
      >
        Go to Dashboard
      </button>
    </div>
  );
}
