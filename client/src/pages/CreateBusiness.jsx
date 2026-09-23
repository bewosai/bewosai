import { useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { auth as authApi } from "../api";
import bewosaiLogo from "../assessts/images/bewosai.png";
import { Building2, ArrowRight, ChevronLeft, Gift } from "lucide-react";
import PhoneInput from "../components/common/PhoneInput";

const BUSINESS_TYPE_PRESETS = [
  "Retail Shop", "Restaurant", "Pharmacy", "Wholesale", "Grocery",
  "Electronics", "Hardware", "Service", "Manufacturing", "Other",
];

function rememberedReferral() {
  try { return localStorage.getItem("pending_referral") || ""; } catch { return ""; }
}

export default function CreateBusinessPage() {
  const { addBusiness, businesses } = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  // A shared referral link (e.g. /create-business?ref=CODE) pre-fills the
  // code but still leaves it editable — see billing app / UpgradePlanPage
  // for where a business's own code comes from.
  const [form, setForm] = useState({ name: "", business_type: "", phone: "", referral_code: searchParams.get("ref") || rememberedReferral() });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [customType, setCustomType] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { setError("Business name is required."); return; }
    setSaving(true);
    try {
      const { data } = await authApi.createBusiness(form);
      addBusiness(data);
      try { localStorage.removeItem("pending_referral"); } catch { /* nothing to clear */ }
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
                placeholder="General Store" className={field} autoFocus />
            </div>
            <div>
              <label className="mb-1.5 block text-sm font-medium text-navy-200">Business Type <span className="text-navy-500">(optional)</span></label>
              <div className="flex flex-wrap gap-1.5">
                {BUSINESS_TYPE_PRESETS.map((preset) => (
                  <button
                    key={preset}
                    type="button"
                    onClick={() => {
                      if (preset === "Other") {
                        setCustomType(true);
                        setForm({ ...form, business_type: "" });
                      } else {
                        setCustomType(false);
                        setForm({ ...form, business_type: preset });
                      }
                    }}
                    className={`rounded-full border px-3 py-1.5 text-xs font-medium transition ${
                      (preset === "Other" ? customType : !customType && form.business_type === preset)
                        ? "border-orange-500 bg-orange-500/10 text-orange-400"
                        : "border-navy-700 text-navy-400 hover:border-navy-600"
                    }`}
                  >
                    {preset}
                  </button>
                ))}
              </div>
              {customType && (
                <input
                  value={form.business_type}
                  onChange={(e) => setForm({ ...form, business_type: e.target.value })}
                  placeholder="Describe your business type"
                  className={`${field} mt-2`}
                  autoFocus
                />
              )}
            </div>
            <div>
              <label className="mb-1.5 block text-sm font-medium text-navy-200">Phone <span className="text-navy-500">(optional)</span></label>
              <PhoneInput value={form.phone} onChange={(phone) => setForm({ ...form, phone })} />
            </div>
            <div>
              <label className="mb-1.5 flex items-center gap-1.5 text-sm font-medium text-navy-200">
                <Gift className="h-3.5 w-3.5 text-orange-400" /> Referral Code <span className="text-navy-500">(optional)</span>
              </label>
              <input
                value={form.referral_code}
                onChange={(e) => setForm({ ...form, referral_code: e.target.value.toUpperCase() })}
                placeholder="Got a code from a friend?"
                className={`${field} font-mono uppercase tracking-widest placeholder:tracking-normal placeholder:font-sans`}
              />
              {form.referral_code && (
                <p className="mt-1.5 text-xs text-navy-500">You and your friend will both get 1 month Premium free.</p>
              )}
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
