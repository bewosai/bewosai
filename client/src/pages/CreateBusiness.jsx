import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { auth as authApi } from "../api";
import bewosaiLogo from "../assessts/images/bewosai.png";
import { Building2, ArrowRight, ChevronLeft } from "lucide-react";

export default function CreateBusinessPage() {
  const { addBusiness, businesses } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ name: "", business_type: "", phone: "" });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setError("Business name is required."); return; }
    setSaving(true);
    try {
      const { data } = await authApi.createBusiness(form);
      addBusiness(data);
      navigate("/dashboard");
    } catch (err) {
      setError(err.response?.data?.name?.[0] || "Failed to create business.");
    } finally {
      setSaving(false);
    }
  };

  const field = "w-full rounded-2xl border border-navy-700 bg-navy-950 px-4 py-3 text-white outline-none transition placeholder:text-navy-500 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20";

  return (
    <div className="flex min-h-screen items-center justify-center bg-navy-950 px-4">
      <div className="w-full max-w-md">
        {/* Only offered when there's an existing business to go back to —
            this page is also the mandatory first-time setup screen right
            after signup, when there's nothing behind it yet. */}
        {businesses.length > 0 && (
          <button
            onClick={() => navigate(-1)}
            className="mb-4 flex items-center gap-1.5 text-sm text-navy-400 hover:text-white"
          >
            <ChevronLeft className="h-4 w-4" /> Back
          </button>
        )}

        <div className="mb-8 flex flex-col items-center gap-3 text-center">
          <img src={bewosaiLogo} alt="Bewosai" className="h-14 w-14 rounded-2xl object-cover shadow-lg shadow-orange-500/20" />
          <h1 className="text-2xl font-extrabold text-white">Set up your business</h1>
          <p className="text-sm text-navy-400">Create your first business profile to get started.</p>
        </div>

        <div className="rounded-3xl border border-navy-800 bg-navy-900/80 p-7 shadow-2xl">
          {error && (
            <div className="mb-4 rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-2.5 text-sm text-red-400">{error}</div>
          )}
          <form onSubmit={submit} className="space-y-4">
            <div>
              <label className="mb-1.5 block text-sm font-medium text-navy-200">Business Name</label>
              <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="Rajan Traders, My Shop..." className={field} autoFocus />
            </div>
            <div>
              <label className="mb-1.5 block text-sm font-medium text-navy-200">Business Type <span className="text-navy-500">(optional)</span></label>
              <input value={form.business_type} onChange={(e) => setForm({ ...form, business_type: e.target.value })}
                placeholder="Retail, Restaurant, Service..." className={field} />
            </div>
            <div>
              <label className="mb-1.5 block text-sm font-medium text-navy-200">Phone <span className="text-navy-500">(optional)</span></label>
              <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })}
                placeholder="98XXXXXXXX" className={field} />
            </div>
            <button type="submit" disabled={saving}
              className="flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-3.5 font-bold text-white transition hover:bg-orange-400 disabled:opacity-60">
              {saving ? "Creating…" : <><Building2 className="h-4 w-4" /> Create Business <ArrowRight className="h-4 w-4" /></>}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
