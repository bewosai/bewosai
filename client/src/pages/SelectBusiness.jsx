import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import bewosaiLogo from "../assessts/images/bewosai.png";
import { Building2, ChevronLeft, ChevronRight, LogOut, Plus } from "lucide-react";

export default function SelectBusinessPage() {
  const { businesses, selectBusiness, currentBusiness, logout, user } = useAuth();
  const navigate = useNavigate();

  function pick(biz) {
    selectBusiness(biz);
    navigate("/dashboard");
  }

  async function handleLogout() {
    await logout();
    navigate("/login", { replace: true });
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-navy-950 px-4">
      <div className="w-full max-w-md">
        {/* Only offered when there's actually a business to return to — this
            page is also the mandatory first-time picker right after login,
            when there's nothing behind it to cancel back to. */}
        {currentBusiness && (
          <button
            onClick={() => navigate(-1)}
            className="mb-4 flex items-center gap-1.5 text-sm text-navy-400 hover:text-white"
          >
            <ChevronLeft className="h-4 w-4" /> Cancel
          </button>
        )}

        <div className="mb-8 flex flex-col items-center gap-3 text-center">
          <img src={bewosaiLogo} alt="Bewosai" className="h-14 w-14 rounded-2xl object-cover shadow-lg shadow-orange-500/20" />
          <h1 className="text-2xl font-extrabold text-white">Select Business</h1>
          <p className="text-sm text-navy-400">
            Hi {user?.name}, choose which business to manage.
          </p>
        </div>

        <div className="space-y-3">
          {businesses.map((biz) => (
            <button key={biz.id} onClick={() => pick(biz)}
              className="flex w-full items-center justify-between rounded-2xl border border-navy-700 bg-navy-900/80 p-5 text-left transition hover:border-orange-500 hover:bg-navy-800">
              <div className="flex items-center gap-4">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-orange-500/15">
                  <Building2 className="h-5 w-5 text-orange-400" />
                </div>
                <div>
                  <p className="font-semibold text-white">{biz.name}</p>
                  <p className="mt-0.5 text-xs text-navy-400 capitalize">{biz.plan?.toLowerCase()} Plan · {biz.status}</p>
                </div>
              </div>
              <ChevronRight className="h-5 w-5 text-navy-500" />
            </button>
          ))}
        </div>

        <button onClick={() => navigate("/create-business")}
          className="mt-4 flex w-full items-center justify-center gap-2 rounded-2xl border border-dashed border-navy-700 py-4 text-sm text-navy-400 transition hover:border-orange-500 hover:text-orange-400">
          <Plus className="h-4 w-4" /> Add Another Business
        </button>

        <button onClick={handleLogout}
          className="mx-auto mt-6 flex items-center gap-1.5 text-xs text-navy-500 hover:text-navy-300">
          <LogOut className="h-3.5 w-3.5" /> Log out
        </button>
      </div>
    </div>
  );
}
